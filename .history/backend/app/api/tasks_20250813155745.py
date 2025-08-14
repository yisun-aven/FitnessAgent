from fastapi import APIRouter, Depends
from typing import List
from datetime import datetime
from uuid import uuid4

from app.models.schemas import Task, TaskCreate, GenerateTasksRequest, GenerateTasksResponse
from app.dependencies.auth import get_current_user
from app.agents.graph import generate_tasks_from_goal

router = APIRouter()

_IN_MEMORY_TASKS: dict[str, list[Task]] = {}


def _user_id(user_obj) -> str:
    return user_obj.get("id")


@router.get("", response_model=List[Task])
async def list_tasks(user_obj = Depends(get_current_user)):
    uid = _user_id(user_obj)
    return _IN_MEMORY_TASKS.get(uid, [])


@router.post("/generate", response_model=GenerateTasksResponse)
async def generate_tasks(req: GenerateTasksRequest, user_obj = Depends(get_current_user)):
    tasks_create = generate_tasks_from_goal(req.goal)
    return GenerateTasksResponse(tasks=tasks_create)


@router.post("/", response_model=Task)
async def create_task(payload: TaskCreate, user_obj = Depends(get_current_user)):
    uid = _user_id(user_obj)
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
