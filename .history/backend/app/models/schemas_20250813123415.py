from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, date


class User(BaseModel):
    id: str
    email: Optional[str] = None


class GoalCreate(BaseModel):
    type: str = Field(example="weight_loss")
    target_value: Optional[float] = Field(default=None, example=5.0)
    target_date: Optional[date] = None


class Goal(BaseModel):
    id: str
    user_id: str
    type: str
    target_value: Optional[float] = None
    target_date: Optional[date] = None
    status: str = "active"
    created_at: datetime


class TaskCreate(BaseModel):
    goal_id: Optional[str] = None
    title: str
    description: Optional[str] = None
    due_at: Optional[datetime] = None


class Task(BaseModel):
    id: str
    user_id: str
    goal_id: Optional[str] = None
    title: str
    description: Optional[str] = None
    due_at: Optional[datetime] = None
    status: str = "pending"
    calendar_event_id: Optional[str] = None
    created_at: datetime


class GenerateTasksRequest(BaseModel):
    goal: GoalCreate


class GenerateTasksResponse(BaseModel):
    tasks: List[TaskCreate]
