# app/agents/context.py
import contextvars

# Per-request context for auth and goal routing
CURRENT_JWT: contextvars.ContextVar[str | None] = contextvars.ContextVar("current_jwt", default=None)
CURRENT_GOAL_ID: contextvars.ContextVar[str | None] = contextvars.ContextVar("current_goal_id", default=None)
