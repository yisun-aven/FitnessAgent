from pydantic import BaseModel, Field
from typing import Optional, List, Any
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


class ProfileBase(BaseModel):
    sex: Optional[str] = None
    dob: Optional[date] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    unit_pref: Optional[str] = None
    activity_level: Optional[str] = None
    fitness_level: Optional[str] = None
    resting_hr: Optional[float] = None
    max_hr: Optional[float] = None
    body_fat_pct: Optional[float] = None
    medical_conditions: Optional[str] = None
    injuries: Optional[str] = None
    timezone: Optional[str] = None
    locale: Optional[str] = None
    availability_days: Optional[List[int]] = None


class Profile(BaseModel):
    id: str
    created_at: Optional[datetime] = None


class ProfileUpsert(ProfileBase):
    pass


class CreateGoalResponse(BaseModel):
    goal: Goal
    agent_output: Optional[Any] = None
