# from fastapi import APIRouter, HTTPException, Query, Path
# from pydantic import BaseModel
# from typing import Any, Dict, Optional
# import json

# from app.agents.graph import get_coach


# router = APIRouter()


# def _maybe_json(content: str) -> Dict[str, Any]:
#     try:
#         return json.loads(content)
#     except Exception:
#         return {"text": content}


# @router.get("/")
# async def list_tasks(
#     user_id: Optional[str] = Query(None),
#     goal_id: Optional[str] = Query(None),
# ) -> Dict[str, Any]:
#     if not user_id and not goal_id:
#         raise HTTPException(status_code=400, detail="Provide user_id or goal_id")
#     coach = await get_coach()
#     if goal_id and user_id:
#         msg = f"List tasks for user {user_id} and goal {goal_id}. Return compact JSON rows."
#     elif goal_id:
#         msg = f"List tasks for goal {goal_id}. Return compact JSON rows."
#     else:
#         msg = f"List tasks for user {user_id}. Return compact JSON rows."
#     final = await coach.ainvoke_chat(user_id=user_id or "unknown", message=msg, goal_id=goal_id)
#     content = final.content if isinstance(final.content, str) else str(final.content)
#     return _maybe_json(content)


# class UpdateTaskRequest(BaseModel):
#     status: Optional[str] = None  # e.g., pending, done, canceled


# @router.patch("/{task_id}")
# async def update_task(
#     task_id: str = Path(...),
#     req: UpdateTaskRequest = ...,
#     user_id: Optional[str] = Query(None),
# ) -> Dict[str, Any]:
#     coach = await get_coach()
#     parts = [f"Update task {task_id}"]
#     if req.status:
#         parts.append(f"set status={req.status}")
#     parts.append("Return compact JSON rows after update.")
#     msg = ". ".join(parts)
#     final = await coach.ainvoke_chat(user_id=user_id or "unknown", message=msg)
#     content = final.content if isinstance(final.content, str) else str(final.content)
#     return _maybe_json(content)
