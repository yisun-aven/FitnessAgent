import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from pydantic import BaseModel
from typing import Optional, Dict, Any
import asyncio
from app.agents.graph import get_coach
import logging
from fastapi import Request
from fastapi.exceptions import HTTPException
from fastapi.responses import JSONResponse
from starlette.requests import Request as StarletteRequest
# NEW: additional imports for auth + headers
from fastapi import Depends, Header
import httpx
from app.dependencies.auth import get_current_user

load_dotenv()

from app.api.goals import router as goals_router
from app.api.schedule import router as schedule_router
from app.api.profile import router as profile_router
from app.api.diagnostics import router as diagnostics_router
from app.dependencies.chat_store import ChatStore

APP_ENV = os.getenv("APP_ENV", "local")

app = FastAPI(title="FitnessAgent API", version="0.1.0")

# CORS for local dev and iOS app
origins = [
    "http://localhost",
    "http://127.0.0.1",
    "http://localhost:5173",
    "capacitor://localhost",
    "ionic://localhost",
    "*",  # tighten later
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

logger = logging.getLogger("uvicorn.error")

@app.middleware("http")
async def log_requests(request: StarletteRequest, call_next):
    logger.info(f"--> {request.method} {request.url.path}")
    try:
        response = await call_next(request)
        logger.info(f"<-- {response.status_code} {request.method} {request.url.path}")
        return response
    except Exception:
        logger.exception(f"!! {request.method} {request.url.path} crashed")
        raise

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    logger.warning(f"HTTPException {exc.status_code} at {request.url.path}: {exc.detail}")
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})

@app.get("/")
async def root():
    return {"status": "ok", "env": APP_ENV}

# Routers
app.include_router(goals_router, prefix="/goals", tags=["goals"]) 
app.include_router(schedule_router, prefix="/schedule", tags=["schedule"]) 
app.include_router(profile_router, prefix="/profile", tags=["profile"])
app.include_router(diagnostics_router, prefix="/diagnostics", tags=["diagnostics"])

# NEW: Supabase REST helpers (mirror profile.py pattern)
_SUPABASE_URL = os.getenv("SUPABASE_URL", "")
_SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")

def _sb_headers(user_token: str) -> dict:
    return {
        "Authorization": f"Bearer {user_token}",
        "apikey": _SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

async def _sb_request(method: str, url: str, *, headers: dict):
    # lightweight wrapper; profile.py has a retry variant if needed
    async with httpx.AsyncClient(timeout=httpx.Timeout(connect=10.0, read=20.0, write=10.0, pool=20.0)) as client:
        return await client.request(method, url, headers=headers)

# -----------------------------
# Coach startup + endpoints
# -----------------------------

@app.on_event("startup")
async def _startup_init_coach():
    # Warm the coach singleton so first chat is fast
    try:
        await get_coach()
        print("[startup] Coach initialized")
    except Exception as e:
        print(f"[startup] Coach init failed: {e}")

class ChatRequest(BaseModel):
    # user_id now optional and validated against JWT if provided
    user_id: Optional[str] = None
    message: str
    goal_id: Optional[str] = None

@app.post("/coach/chat")
async def coach_chat(
    req: ChatRequest,
    user_obj = Depends(get_current_user),
    authorization: str | None = Header(default=None),
) -> Dict[str, Any]:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]
    uid = user_obj.get("id")

    # If client sent user_id, enforce it matches JWT-derived uid
    if req.user_id and req.user_id.lower() != uid:
        raise HTTPException(status_code=403, detail="user_id does not match authenticated user")

    # If goal_id provided, verify ownership via RLS using user's JWT
    if req.goal_id:
        if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
            raise HTTPException(status_code=500, detail="Supabase not configured")
        url = f"{_SUPABASE_URL}/rest/v1/goals?select=id&id=eq.{req.goal_id}"
        resp = await _sb_request("GET", url, headers=_sb_headers(token))
        if resp.status_code != 200:
            raise HTTPException(status_code=resp.status_code, detail="Failed to verify goal ownership")
        rows = []
        try:
            rows = resp.json() if isinstance(resp.json(), list) else []
        except Exception:
            rows = []
        if not rows:
            raise HTTPException(status_code=404, detail="Goal not found or not owned by user")

    coach = await get_coach()
    final = await coach.ainvoke_chat(user_id=uid, user_jwt=token, message=req.message, goal_id=req.goal_id)
    return {"role": "assistant", "content": final.content}

@app.get("/coach/progress")
async def coach_progress(goal_id: str) -> Dict[str, Any]:
    coach = await get_coach()
    return coach.progress(goal_id)

@app.get("/coach/history")
async def get_chat_history(
    goal_id: Optional[str] = None,
    limit: int = 200,
    user_obj = Depends(get_current_user),
    authorization: str | None = Header(default=None),
):
    """Return persisted chat history for the authenticated user (and optional goal_id).
    Messages are returned oldest→newest so the UI can render directly.
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    uid = user_obj.get("id")
    try:
        store = ChatStore()
        conv_id = store.find_conversation(user_id=uid, goal_id=goal_id)
        if not conv_id:
            return {"conversation_id": None, "messages": []}
        rows = store.fetch_messages_asc(conversation_id=conv_id, limit_n=limit)
        messages = [
            {
                "role": r.get("role"),
                "content": r.get("content", {}),
                "created_at": r.get("created_at"),
            }
            for r in (rows or [])
        ]
        return {"conversation_id": conv_id, "messages": messages}
    except Exception as e:
        # Surface a helpful error
        raise HTTPException(status_code=500, detail=f"Failed to load chat history: {e}")
