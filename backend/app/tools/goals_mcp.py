# app/tools/goals_mcp.py
from typing import Any, Dict, Tuple
from langchain_core.tools import tool
from app.agents.context import CURRENT_JWT, CURRENT_GOAL_ID


def make_goals_mcp_tools(goals_tool_map: Dict[str, Any]) -> Tuple[Any, Any]:
    """Return LangChain tool wrappers for the MCP Goals server tools.

    Tools returned:
    - mcp_get_goals(limit: int = 20) -> dict
    - mcp_get_goal_tasks(goal_id: str, limit: int = 50) -> dict
    """

    @tool("get_goals")
    async def mcp_get_goals(limit: int = 20) -> dict:
        """Fetch the current user's goals via MCP (RLS enforced). Returns {items, count, next_cursor, as_of, truncated}."""
        jwt = CURRENT_JWT.get()
        if not jwt:
            raise PermissionError("jwt_missing: user JWT is required for RLS; please reauthenticate(client)")
        try:
            tool_impl = goals_tool_map.get("get_goals")
            if tool_impl is None:
                raise RuntimeError("mcp_tool_not_found: goals.get_goals not available")
            result = await tool_impl.ainvoke(
                {"args": {"limit": int(limit), "jwt": jwt}},
                config={"metadata": {"Authorization": f"Bearer {jwt}"}},
            )
            return result if isinstance(result, dict) else {"items": result or [], "count": len(result or []), "next_cursor": None, "as_of": None, "truncated": False}
        except Exception as e:
            raise RuntimeError(f"mcp:get_goals_failed: {e}")

    @tool("get_goal_tasks")
    async def mcp_get_goal_tasks(goal_id: str, limit: int = 50) -> dict:
        """Fetch tasks for a specific goal via MCP (RLS enforced). Returns {items, count, next_cursor, as_of, truncated}."""
        jwt = CURRENT_JWT.get()
        gid = goal_id or CURRENT_GOAL_ID.get()
        if not jwt:
            raise PermissionError("jwt_missing: user JWT is required for RLS; please reauthenticate")
        if not gid:
            raise ValueError("goal_id_missing: a goal_id must be provided or set in context")
        try:
            tool_impl = goals_tool_map.get("get_goal_tasks")
            if tool_impl is None:
                raise RuntimeError("mcp_tool_not_found: goals.get_goal_tasks not available")
            result = await tool_impl.ainvoke(
                {"args": {"goal_id": gid, "limit": int(limit), "jwt": jwt}},
                config={"metadata": {"Authorization": f"Bearer {jwt}"}},
            )
            return result if isinstance(result, dict) else {"items": result or [], "count": len(result or []), "next_cursor": None, "as_of": None, "truncated": False}
        except Exception as e:
            raise RuntimeError(f"mcp:get_goal_tasks_failed: {e}")

    return mcp_get_goals, mcp_get_goal_tasks
