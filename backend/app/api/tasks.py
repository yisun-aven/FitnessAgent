from fastapi import APIRouter, Depends, Header, HTTPException
from typing import List
from datetime import datetime
from uuid import uuid4
import os
import httpx

from app.models.schemas import Task, TaskCreate, GenerateTasksRequest, GenerateTasksResponse
from app.dependencies.auth import get_current_user
from app.agents.graph import generate_tasks_from_goal

router = APIRouter()

_SUPABASE_URL = os.getenv("SUPABASE_URL", "")
_SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")

_IN_MEMORY_TASKS: dict[str, list[Task]] = {}


def _user_id(user_obj) -> str:
    return user_obj.get("id")


def _sb_headers(user_token: str) -> dict:
    return {
        "Authorization": f"Bearer {user_token}",
        "apikey": _SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }


@router.get("", response_model=List[Task])
async def list_tasks(
    goal_id: str | None = None,
    user_obj = Depends(get_current_user),
    authorization: str | None = Header(default=None),
):
    uid = _user_id(user_obj)
    print(f"[tasks.list] uid={uid}")  # TEMP: debug which user's tasks are fetched

    # Fallback to in-memory if Supabase not configured
    if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
        data = _IN_MEMORY_TASKS.get(uid, [])
        if goal_id:
            data = [t for t in data if t.goal_id == goal_id]
        return data

    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]

    url = f"{_SUPABASE_URL}/rest/v1/tasks?select=*&user_id=eq.{uid}&order=created_at.desc"
    if goal_id:
        url += f"&goal_id=eq.{goal_id}"
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(url, headers=_sb_headers(token))
    if resp.status_code != 200:
        print(f"[tasks.list] supabase error {resp.status_code}: {resp.text}")
        raise HTTPException(status_code=resp.status_code, detail="Failed to fetch tasks")
    return resp.json()


@router.post("/generate", response_model=GenerateTasksResponse)
async def generate_tasks(
    req: GenerateTasksRequest,
    goal_id: str | None = None,
    user_obj = Depends(get_current_user),
    authorization: str | None = Header(default=None),
):
    uid = _user_id(user_obj)
    tasks_create = generate_tasks_from_goal(req.goal)

    # Persist generated tasks to Supabase if configured (mock persistence). We do not attach goal_id for now.
    if _SUPABASE_URL and _SUPABASE_ANON_KEY and tasks_create:
        if not authorization or not authorization.lower().startswith("bearer "):
            raise HTTPException(status_code=401, detail="Missing bearer token")
        token = authorization.split(" ", 1)[1]
        payload = [
            {
                "user_id": uid,
                # Prefer explicit goal_id from query param; fall back to each task's goal_id if present.
                "goal_id": goal_id or getattr(tc, "goal_id", None),
                "title": tc.title,
                "description": tc.description,
                "due_at": tc.due_at.isoformat() if tc.due_at else None,
                "status": "pending",
            }
            for tc in tasks_create
        ]
        url = f"{_SUPABASE_URL}/rest/v1/tasks"
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(url, headers=_sb_headers(token), json=payload)
        if resp.status_code not in (200, 201):
            print(f"[tasks.generate] supabase insert error {resp.status_code}: {resp.text}")
            # Don't fail the response; still return generated tasks to UI

    return GenerateTasksResponse(tasks=tasks_create)


@router.post("", response_model=Task)
async def create_task(payload: TaskCreate, user_obj = Depends(get_current_user), authorization: str | None = Header(default=None)):
    uid = _user_id(user_obj)

    # Fallback to in-memory if Supabase not configured
    if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
        t = Task(
            id=str(uuid4()),
            user_id=uid,
            goal_id=payload.goal_id,
            title=payload.title,
            description=payload.description,
            due_at=payload.due_at,
            status="pending",
            calendar_event_id=None,
            created_at=datetime.utcnow(),
        )
        _IN_MEMORY_TASKS.setdefault(uid, []).append(t)
        return t

    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]

    body = {
        "user_id": uid,
        "goal_id": payload.goal_id,
        "title": payload.title,
        "description": payload.description,
        "due_at": payload.due_at.isoformat() if payload.due_at else None,
        "status": "pending",
        "calendar_event_id": None,
    }
    url = f"{_SUPABASE_URL}/rest/v1/tasks"
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(url, headers=_sb_headers(token), json=body)
    if resp.status_code not in (200, 201):
        print(f"[tasks.create] supabase error {resp.status_code}: {resp.text}")
        raise HTTPException(status_code=resp.status_code, detail="Failed to create task")
    created = resp.json()
    if isinstance(created, list) and created:
        created = created[0]
    return created
