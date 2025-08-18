from typing import List, Optional, TypedDict
from pydantic import BaseModel, Field
from mcp.server.fastmcp import FastMCP, Context
from app.models.schemas import Goal
import logging

mcp = FastMCP("Goals")

# Basic logger for the MCP Goals server
logger = logging.getLogger("goals_mcp")
if not logger.handlers:
    logging.basicConfig(level=logging.INFO, format="[GOALS_MCP] %(levelname)s %(message)s")
logger.setLevel(logging.INFO)

class GetGoalsArgs(BaseModel):
    user_id: str = Field(..., description="Supabase UUID for the user")
    limit: int = Field(20, ge=1, le=200, description="Max rows to return")

class GetGoalTasksArgs(BaseModel):
    goal_id: str = Field(..., description="UUID of the goal to fetch tasks for")
    limit: int = Field(50, ge=1, le=200, description="Max rows to return")

@mcp.tool()
def get_goals(ctx: Context, args: GetGoalsArgs) -> List[dict]:
    """
    Get goals for a user via Supabase.
    Uses env from server process (e.g., SUPABASE_URL/KEY).
    """
    from supabase import create_client
    import os

    logger.info("get_goals called: user_id=%s limit=%s", args.user_id, args.limit)
    try:
        url = os.environ.get("SUPABASE_URL")
        service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        anon_key = os.environ.get("SUPABASE_ANON_KEY")
        key = service_key or anon_key
        logger.info(
            "env present: SUPABASE_URL=%s SERVICE_ROLE_KEY=%s ANON_KEY=%s using=%s",
            bool(url), bool(service_key), bool(anon_key),
            "service_role" if service_key else ("anon" if anon_key else "none"),
        )
        if not url or not key:
            logger.error("Missing Supabase credentials in environment")
            return []

        supa = create_client(url, key)

        # Prefer exact match; if no rows and user_id has uppercase letters, try lowercase
        uid = args.user_id
        q = supa.table("goals").select("*").eq("user_id", uid).limit(args.limit)
        logger.info("query prepared for table 'goals'")
        resp = q.execute()
        data = resp.data or []
        if not data and any(c.isalpha() and c.isupper() for c in uid):
            logger.info("no rows with exact match; retrying with lowercase user_id")
            uid_l = uid.lower()
            resp = supa.table("goals").select("*").eq("user_id", uid_l).limit(args.limit).execute()
            data = resp.data or []
        logger.info("rows=%d first_row=%s", len(data), data[0] if data else None)
        # Return plain dicts to ensure MCP tool output is JSON-serializable
        return data
    except Exception:
        logger.exception("get_goals failed")
        # Fail safe: return empty list so the caller doesn’t crash
        return []

@mcp.tool()
def get_goal_tasks(ctx: Context, args: GetGoalTasksArgs) -> List[dict]:
    """
    Return tasks for a specific goal (ordered by due_at ascending).
    """
    from supabase import create_client
    import os

    logger.info("get_goal_tasks called: goal_id=%s limit=%s", args.goal_id, args.limit)
    try:
        url = os.environ.get("SUPABASE_URL")
        service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        anon_key = os.environ.get("SUPABASE_ANON_KEY")
        key = service_key or anon_key
        logger.info(
            "env present: SUPABASE_URL=%s SERVICE_ROLE_KEY=%s ANON_KEY=%s using=%s",
            bool(url), bool(service_key), bool(anon_key),
            "service_role" if service_key else ("anon" if anon_key else "none"),
        )
        if not url or not key:
            logger.error("Missing Supabase credentials in environment")
            return []

        supa = create_client(url, key)
        q = (
            supa
            .table("tasks")
            .select("*")
            .eq("goal_id", args.goal_id)
            .order("due_at", desc=False)
            .limit(args.limit)
        )
        logger.info("query prepared for table 'tasks'")
        resp = q.execute()
        data = resp.data or []
        logger.info("rows=%d first_row=%s", len(data), data[0] if data else None)
        return data
    except Exception:
        logger.exception("get_goal_tasks failed")
        return []

if __name__ == "__main__":
    mcp.run(transport="stdio")
