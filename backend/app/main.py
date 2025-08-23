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
    user_id: str
    message: str
    goal_id: Optional[str] = None

@app.post("/coach/chat")
async def coach_chat(req: ChatRequest) -> Dict[str, Any]:
    coach = await get_coach()
    final = await coach.ainvoke_chat(user_id=req.user_id, message=req.message, goal_id=req.goal_id)
    return {"role": "assistant", "content": final.content}

@app.get("/coach/progress")
async def coach_progress(goal_id: str) -> Dict[str, Any]:
    coach = await get_coach()
    return coach.progress(goal_id)

@app.get("/coach/history")
async def get_chat_history(user_id: str, goal_id: Optional[str] = None, limit: int = 200):
    """Return persisted chat history for a given (user_id, goal_id?).
    Messages are returned oldest→newest so the UI can render directly.
    """
    try:
        store = ChatStore()
        conv_id = store.find_conversation(user_id=user_id, goal_id=goal_id)
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
