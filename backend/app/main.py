import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()

from app.api.goals import router as goals_router
from app.api.tasks import router as tasks_router
from app.api.schedule import router as schedule_router

APP_ENV = os.getenv("APP_ENV", "local")

app = FastAPI(title="FitnessAgent API", version="0.1.0")

# CORS for local dev and iOS app
origins = [
    "http://localhost",
    "http://127.0.0.1",
    "http://localhost:5173",
    "capacitor://localhost",
    "ionic://localhost",
    "*",  # tighten later
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)


@app.get("/")
async def root():
    return {"status": "ok", "env": APP_ENV}


# Routers
app.include_router(goals_router, prefix="/goals", tags=["goals"]) 
app.include_router(tasks_router, prefix="/tasks", tags=["tasks"]) 
app.include_router(schedule_router, prefix="/schedule", tags=["schedule"]) 
