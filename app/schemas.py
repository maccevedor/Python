from pydantic import BaseModel, Field
from datetime import datetime
from typing import Optional
from app.models import TaskStatus


class TaskCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None


class TaskUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    status: Optional[TaskStatus] = None


class TaskResponse(BaseModel):
    id: int
    title: str
    description: Optional[str]
    status: TaskStatus
    created_at: datetime
    updated_at: Optional[datetime]
    result: Optional[str]

    class Config:
        from_attributes = True


class MessageResponse(BaseModel):
    message: str
    task_id: Optional[int] = None
