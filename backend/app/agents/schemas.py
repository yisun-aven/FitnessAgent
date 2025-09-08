# app/agents/schemas.py
from pydantic import BaseModel
from typing import List

class TaskModel(BaseModel):
    title: str
    description: str
    due_at: str
    status: str

class ItemsModel(BaseModel):
    items: List[TaskModel]
