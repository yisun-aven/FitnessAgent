from fastapi import APIRouter, Depends
from typing import List, Dict
from uuid import uuid4

from app.dependencies.auth import get_current_user

router = APIRouter()


@router.post("/")
async def schedule_tasks(tasks: List[Dict], user_obj = Depends(get_current_user)):
    # Stub: pretend we created calendar events for each task
    results = []
    for _ in tasks:
        results.append({"calendar_event_id": f"evt_{uuid4().hex[:8]}"})
    return {"scheduled": results}
