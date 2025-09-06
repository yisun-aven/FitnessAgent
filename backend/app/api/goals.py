from fastapi import APIRouter, Depends, Header, HTTPException
from typing import List
from datetime import datetime
from uuid import uuid4
import os
import httpx
import json

from app.models.schemas import Goal, GoalCreate, User, CreateGoalResponse, Task
from app.dependencies.auth import get_current_user
from app.agents.graph import get_coach
from app.api.profile import get_my_profile
from app.agents.client import FitnessCoach
from langchain_core.messages import SystemMessage, AIMessage
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

@router.post("", response_model=CreateGoalResponse)        # <- no trailing slash
async def create_goal(payload: GoalCreate, user_obj = Depends(get_current_user), authorization: str | None = Header(default=None)):
    user = _user_from_supabase(user_obj)
    if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
        # Fallback to in-memory if Supabase not configured
        # Enforce: only one active goal per type per user
        existing = [g for g in _IN_MEMORY_GOALS.get(user.id, []) if g.type == payload.type and g.status == "active"]
        if existing:
            raise HTTPException(status_code=409, detail=f"Active goal of type '{payload.type}' already exists")
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
        return {"goal": g, "agent_output": None}
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]

    # Supabase pre-check: only one active goal per type per user
    check_url = f"{_SUPABASE_URL}/rest/v1/goals?select=id&user_id=eq.{user.id}&type=eq.{payload.type}&status=eq.active&limit=1"
    async with httpx.AsyncClient(timeout=10) as client:
        pre = await client.get(check_url, headers=_sb_headers(token))
    if pre.status_code == 200:
        try:
            existing = pre.json()
            if isinstance(existing, list) and len(existing) > 0:
                raise HTTPException(status_code=409, detail=f"Active goal of type '{payload.type}' already exists")
        except HTTPException:
            raise
        except Exception as e:
            # If parsing fails, continue to attempt creation; server-side RLS/constraints may still protect
            print(f"[goals.create] precheck parse error: {e}")
    else:
        print(f"[goals.create] precheck error {pre.status_code}: {pre.text}")

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
    print(f"[goals.create] supabase created goal {created}")
    # Supabase returns a list when Prefer return=representation and single object
    if isinstance(created, list) and created:
        created = created[0]
    # ok, so now we have "created", which is a goal object.
    # We will give it to the goal agent directly. 
    # The goal agent will not have to fetch from db again, we will directly pass the
    #    - User profile
    #    - created object (goal)

    user_profile = await get_my_profile(user_obj, authorization)
    coach_service = await get_coach()
    # Access the underlying FitnessCoach instance prepared by CoachService
    coach_impl = coach_service._coach
    goal_agent = getattr(coach_impl, "goals_agent", None)
    tracer = getattr(coach_impl, "tracer", None)

    # Prefer direct deterministic generation via domain sub-agents (use initialized coach_impl)
    parsed_items: list[dict] = []
    try:
        direct = await coach_impl.generate_tasks_direct(
            user_profile=user_profile,
            goal=created,
            #existing_tasks_summary=existing_tasks_summary,
        )
        parsed_items = direct.get("items", []) if isinstance(direct, dict) else []
        print(f"[goals.create] direct_merge items_count={len(parsed_items)}")
    except Exception as e:
        print(f"[goals.create] direct_generation_error: {e}")

    # No fallback: direct deterministic domain generation only
    print(f"[goals.create] items_count={len(parsed_items)}")
    if not parsed_items:
        raise HTTPException(status_code=400, detail="Agent returned no tasks to create.")

    # Persist parsed tasks to Supabase (best-effort)
    if parsed_items and isinstance(parsed_items, (list, tuple)) and _SUPABASE_URL and _SUPABASE_ANON_KEY:
        try:
            tasks_rows = []
            for item in parsed_items:
                if not isinstance(item, dict):
                    continue
                tasks_rows.append({
                    # Let Supabase generate id/created_at if defaults exist
                    "user_id": user.id,
                    "goal_id": created.get("id"),
                    "title": item.get("title"),
                    "description": item.get("description"),
                    "due_at": item.get("due_at"),
                    "status": item.get("status", "pending"),
                })
            if tasks_rows:
                tasks_url = f"{_SUPABASE_URL}/rest/v1/tasks"
                async with httpx.AsyncClient(timeout=10) as client:
                    t_resp = await client.post(tasks_url, headers=_sb_headers(token), json=tasks_rows)
                if t_resp.status_code not in (200, 201):
                    print(f"[goals.create] tasks insert error {t_resp.status_code}: {t_resp.text}")
                else:
                    try:
                        inserted = t_resp.json()
                        count = len(inserted) if isinstance(inserted, list) else 1
                    except Exception:
                        count = len(tasks_rows)
                    print(f"[goals.create] inserted {count} tasks for goal={created.get('id')}")
        except Exception as e:
            print(f"[goals.create] failed to persist tasks: {e}")

    return {"goal": created, "agent_output": parsed_items}

@router.delete("/{goal_id}", status_code=204)
async def delete_goal(goal_id: str, user_obj = Depends(get_current_user), authorization: str | None = Header(default=None)) -> None:
    """Delete a goal owned by the authenticated user via Supabase REST with RLS.
    Returns 204 on success, 404 if not found or not owned by the authenticated user.
    """
    if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]

    url = f"{_SUPABASE_URL}/rest/v1/goals?id=eq.{goal_id}"
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.request("DELETE", url, headers=_sb_headers(token))

    if resp.status_code == 200:
        try:
            data = resp.json()
            # If representation is empty, no row was deleted (not found or not owned)
            if not isinstance(data, list) or len(data) == 0:
                raise HTTPException(status_code=404, detail="Goal not found or not owned by user")
            return
        except HTTPException:
            raise
        except Exception:
            # Treat 200 without parseable body as success
            return
    if resp.status_code == 204:
        return

    if resp.status_code in (401, 403):
        raise HTTPException(status_code=resp.status_code, detail="Not authorized to delete this goal")

    # For FK violations or other errors, propagate status/text
    raise HTTPException(status_code=resp.status_code, detail=resp.text)

@router.get("/{goal_id}/tasks", response_model=List[Task])
async def list_goal_tasks(goal_id: str, user_obj = Depends(get_current_user), authorization: str | None = Header(default=None)):
    """List tasks for a given goal, newest first."""
    if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]

    url = f"{_SUPABASE_URL}/rest/v1/tasks?select=*&goal_id=eq.{goal_id}&order=created_at.desc"
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(url, headers=_sb_headers(token))
    if resp.status_code != 200:
        print(f"[goals.tasks] supabase error {resp.status_code}: {resp.text}")
        raise HTTPException(status_code=resp.status_code, detail="Failed to fetch tasks")
    return resp.json()