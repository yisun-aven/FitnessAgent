from fastapi import APIRouter, Depends, Header, HTTPException
from typing import List
from datetime import datetime
from uuid import uuid4
import os
import httpx

from app.models.schemas import Goal, GoalCreate, User
from app.dependencies.auth import get_current_user
router = APIRouter()

_SUPABASE_URL = os.getenv("SUPABASE_URL", "")
_SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")

_IN_MEMORY_GOALS: dict[str, list[Goal]] = {}

def _user_from_supabase(user_obj) -> User:
    return User(id=user_obj.get("id"), email=user_obj.get("email"))

def _sb_headers(user_token: str) -> dict:
    return {
        "Authorization": f"Bearer {user_token}",
        "apikey": _SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

@router.get("", response_model=List[Goal])   # <- no trailing slash
async def list_goals(user_obj = Depends(get_current_user), authorization: str | None = Header(default=None)):
    user = _user_from_supabase(user_obj)
    if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
        # Fallback to in-memory for local misconfig
        goals = _IN_MEMORY_GOALS.get(user.id, [])
        print(f"[goals.list] (mem) uid={user.id} count={len(goals)}")
        return goals
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]

    url = f"{_SUPABASE_URL}/rest/v1/goals?select=*&user_id=eq.{user.id}&order=created_at.desc"
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(url, headers=_sb_headers(token))
    if resp.status_code != 200:
        print(f"[goals.list] supabase error {resp.status_code}: {resp.text}")
        raise HTTPException(status_code=resp.status_code, detail="Failed to fetch goals")
    data = resp.json()
    print(f"[goals.list] uid={user.id} count={len(data)}")  # TEMP debug
    # httpx/json returns list[dict], Pydantic will coerce to List[Goal]
    return data

@router.post("", response_model=Goal)        # <- no trailing slash
async def create_goal(payload: GoalCreate, user_obj = Depends(get_current_user), authorization: str | None = Header(default=None)):
    user = _user_from_supabase(user_obj)
    if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
        # Fallback to in-memory if Supabase not configured
        g = Goal(
            id=str(uuid4()),
            user_id=user.id,
            type=payload.type,
            target_value=payload.target_value,
            target_date=payload.target_date,
            status="active",
            created_at=datetime.utcnow(),
        )
        _IN_MEMORY_GOALS.setdefault(user.id, []).append(g)
        return g
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]

    body = {
        "user_id": user.id,
        "type": payload.type,
        "target_value": payload.target_value,
        "target_date": payload.target_date.isoformat() if payload.target_date else None,
        "status": "active",
    }
    url = f"{_SUPABASE_URL}/rest/v1/goals"
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(url, headers=_sb_headers(token), json=body)
    if resp.status_code not in (200, 201):
        print(f"[goals.create] supabase error {resp.status_code}: {resp.text}")
        raise HTTPException(status_code=resp.status_code, detail="Failed to create goal")
    created = resp.json()
    # Supabase returns a list when Prefer return=representation and single object
    if isinstance(created, list) and created:
        created = created[0]
    return created
