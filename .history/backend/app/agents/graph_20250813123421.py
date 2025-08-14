from typing import List
from app.models.schemas import GoalCreate, TaskCreate

# Placeholder for a future LangGraph graph. For now, return simple tasks.

def generate_tasks_from_goal(goal: GoalCreate) -> List[TaskCreate]:
    tasks: List[TaskCreate] = []
    goal_type = goal.type
    if goal_type == "weight_loss":
        tasks.append(TaskCreate(title="30-min brisk walk", description="Daily walking routine"))
        tasks.append(TaskCreate(title="Meal prep", description="Prepare 3 days of high-protein meals"))
        tasks.append(TaskCreate(title="Gym session", description="Full-body workout (machines)",))
    else:
        tasks.append(TaskCreate(title="Healthy grocery run", description="Buy whole foods and veggies"))
        tasks.append(TaskCreate(title="Stretching", description="10-min morning stretch"))
    return tasks
