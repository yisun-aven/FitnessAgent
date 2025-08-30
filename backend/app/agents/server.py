from typing import List, Optional, TypedDict, Any, Dict
from pydantic import BaseModel, Field
from mcp.server.fastmcp import FastMCP, Context
from app.models.schemas import Goal
import logging
import os
import httpx
from datetime import datetime, timezone

mcp = FastMCP("Goals")

# Basic logger for the MCP Goals server
logger = logging.getLogger("goals_mcp")
if not logger.handlers:
    logging.basicConfig(level=logging.INFO, format="[GOALS_MCP] %(levelname)s %(message)s")
logger.setLevel(logging.INFO)

# --- Env config (no service role; RLS via user JWT) ---
SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "")

def _sb_headers(jwt: str) -> dict:
    return {
        "Authorization": f"Bearer {jwt}",
        "apikey": SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
        # Ask Supabase to include total count in Content-Range
        "Prefer": "count=exact,return=representation",
    }

def _jwt_from_context(ctx: Context, args_jwt: Optional[str] = None) -> Optional[str]:
    """Extract JWT from MCP Context metadata, preferring transport-provided auth.

    Looks for common keys like Authorization/authorization in ctx.metadata. If not found,
    falls back to args_jwt (deprecated path) to keep compatibility during migration.
    """
    try:
        meta: Dict[str, Any] = getattr(ctx, "metadata", {}) or {}
        # Direct header-like
        auth = meta.get("Authorization") or meta.get("authorization")
        if isinstance(auth, str) and auth:
            token = auth.split(" ", 1)[1] if auth.lower().startswith("bearer ") and " " in auth else auth
            logger.info("JWT extracted from metadata: %s", token)
            return token
        # Nested headers map if provided
        headers = meta.get("headers") or {}
        if isinstance(headers, dict):
            h_auth = headers.get("Authorization") or headers.get("authorization")
            if isinstance(h_auth, str) and h_auth:
                token = h_auth.split(" ", 1)[1] if h_auth.lower().startswith("bearer ") and " " in h_auth else h_auth
                return token
    except Exception:
        # Do not fail metadata parsing; fall through to args_jwt
        logger.debug("failed to parse ctx.metadata for JWT", exc_info=True)
    if args_jwt:
        logger.warning("jwt_in_args_used: falling back to args.jwt; prefer transport metadata")
        return args_jwt
    return None

class GetGoalsArgs(BaseModel):
    limit: int = Field(20, ge=1, le=200, description="Max rows to return")
    # TEMP: JWT fallback until metadata propagation is verified. Do NOT log this.
    # TODO: Remove this field when client metadata reliably reaches ctx.metadata.
    jwt: Optional[str] = Field(
        None,
        description="Bearer JWT for RLS (temporary fallback; prefer transport metadata)",
        exclude=True,
        repr=False,
    )

class GetGoalTasksArgs(BaseModel):
    goal_id: str = Field(..., description="UUID of the goal to fetch tasks for")
    limit: int = Field(50, ge=1, le=200, description="Max rows to return")
    # TEMP: see note above.
    jwt: Optional[str] = Field(
        None,
        description="Bearer JWT for RLS (temporary fallback; prefer transport metadata)",
        exclude=True,
        repr=False,
    )

@mcp.tool()
def get_goals(ctx: Context, args: GetGoalsArgs) -> Dict[str, Any]:
    """
    Get YOUR goals (RLS-enforced) via Supabase REST using the provided JWT.
    """
    logger.info("get_goals called: limit=%s", args.limit)
    if not SUPABASE_URL or not SUPABASE_ANON_KEY:
        logger.error("Missing SUPABASE_URL/ANON_KEY in environment")
        raise EnvironmentError("supabase_env_missing: SUPABASE_URL/ANON_KEY are required")
    # Avoid logging ctx or tokens; safe diagnostics are emitted inside _jwt_from_context
    jwt = _jwt_from_context(ctx, args.jwt)
    if not jwt:
        logger.warning("No JWT provided to get_goals (metadata or args)")
        raise PermissionError("jwt_missing: user JWT is required for RLS; please reauthenticate")

    url = f"{SUPABASE_URL}/rest/v1/goals?select=*&order=created_at.desc&limit={int(args.limit)}"
    try:
        with httpx.Client(timeout=httpx.Timeout(connect=10.0, read=20.0, write=10.0, pool=20.0)) as client:
            resp = client.get(url, headers=_sb_headers(jwt))
        if resp.status_code != 200:
            logger.warning("Supabase REST error: %s %s", resp.status_code, resp.text[:200])
            raise RuntimeError(f"rest_error:{resp.status_code}: {resp.text[:200]}")
        data = resp.json() or []
        items = data if isinstance(data, list) else []
        # Parse count from Content-Range if present: e.g. items 0-9/42
        content_range = resp.headers.get("content-range") or resp.headers.get("Content-Range")
        total_count: Optional[int] = None
        if isinstance(content_range, str) and "/" in content_range:
            try:
                total_count = int(content_range.split("/")[-1])
            except Exception:
                total_count = None
        count = total_count if total_count is not None else len(items)
        truncated = len(items) >= int(args.limit)
        as_of = datetime.now(timezone.utc).isoformat()
        return {
            "items": items,
            "count": count,
            "next_cursor": None,  # optional future: implement keyset/offset cursor
            "as_of": as_of,
            "truncated": truncated,
        }
    except Exception:
        logger.exception("get_goals failed")
        raise

@mcp.tool()
def get_goal_tasks(ctx: Context, args: GetGoalTasksArgs) -> Dict[str, Any]:
    """
    Return tasks for YOUR goal (RLS-enforced) via Supabase REST using the provided JWT.
    """
    logger.info("get_goal_tasks called: goal_id=%s limit=%s", args.goal_id, args.limit)
    if not SUPABASE_URL or not SUPABASE_ANON_KEY:
        logger.error("Missing SUPABASE_URL/ANON_KEY in environment")
        raise EnvironmentError("supabase_env_missing: SUPABASE_URL/ANON_KEY are required")
    jwt = _jwt_from_context(ctx, args.jwt)
    if not jwt:
        logger.warning("No JWT provided to get_goal_tasks (metadata or args)")
        raise PermissionError("jwt_missing: user JWT is required for RLS; please reauthenticate")

    url = (
        f"{SUPABASE_URL}/rest/v1/tasks?select=*&goal_id=eq.{args.goal_id}"
        f"&order=due_at.asc&limit={int(args.limit)}"
    )
    try:
        with httpx.Client(timeout=httpx.Timeout(connect=10.0, read=20.0, write=10.0, pool=20.0)) as client:
            resp = client.get(url, headers=_sb_headers(jwt))
        if resp.status_code != 200:
            logger.warning("Supabase REST error: %s %s", resp.status_code, resp.text[:200])
            raise RuntimeError(f"rest_error:{resp.status_code}: {resp.text[:200]}")
        data = resp.json() or []
        items = data if isinstance(data, list) else []
        content_range = resp.headers.get("content-range") or resp.headers.get("Content-Range")
        total_count: Optional[int] = None
        if isinstance(content_range, str) and "/" in content_range:
            try:
                total_count = int(content_range.split("/")[-1])
            except Exception:
                total_count = None
        count = total_count if total_count is not None else len(items)
        truncated = len(items) >= int(args.limit)
        as_of = datetime.now(timezone.utc).isoformat()
        return {
            "items": items,
            "count": count,
            "next_cursor": None,
            "as_of": as_of,
            "truncated": truncated,
        }
    except Exception:
        logger.exception("get_goal_tasks failed")
        raise

if __name__ == "__main__":
    mcp.run(transport="stdio")
