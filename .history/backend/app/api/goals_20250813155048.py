from fastapi import APIRouter, Depends, Header, HTTPException
from typing import List
from datetime import datetime
from uuid import uuid4

from app.models.schemas import Goal, GoalCreate, User
from app.dependencies.auth import get_current_user

router = APIRouter(prefix="/goals", tags=["goals"])

_IN_MEMORY_GOALS: dict[str, list[Goal]] = {}

def _user_from_supabase(user_obj) -> User:
    return User(id=user_obj.get("id"), email=user_obj.get("email"))

@router.get("", response_model=List[Goal])   # <- no trailing slash
async def list_goals(user_obj = Depends(get_current_user)):
    user = _user_from_supabase(user_obj)
    return _IN_MEMORY_GOALS.get(user.id, [])

@router.post("", response_model=Goal)        # <- no trailing slash
async def create_goal(payload: GoalCreate, user_obj = Depends(get_current_user)):
    user = _user_from_supabase(user_obj)
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
