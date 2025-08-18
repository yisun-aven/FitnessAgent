from fastapi import APIRouter, HTTPException
from typing import Dict, Any
from pydantic import BaseModel

from app.agents.graph import get_coach
from app.agents.client import FitnessCoach

router = APIRouter()


@router.get("/mcp/tools")
async def list_mcp_tools() -> Dict[str, Any]:
    # Instantiate a lightweight coach and ask for tools directly
    coach = FitnessCoach()
    tools = await coach.mcp_client.get_tools(server_name="supabase")
    return {"count": len(tools), "tool_names": [t.name for t in tools]}


class SQLDiagRequest(BaseModel):
    user_id: str
    sql: str


@router.post("/mcp/sql")
async def run_sql_via_agent(req: SQLDiagRequest) -> Dict[str, Any]:
    coach = await get_coach()
    # Ask the supervisor to run the provided SQL; the sql_agent will pick it up
    message = (
        "Diagnostic: run the following SQL verbatim via the Supabase tool and return compact JSON rows. "
        f"SQL: {req.sql}"
    )
    final = await coach.ainvoke_chat(user_id=req.user_id, message=message)
    content = final.content if isinstance(final.content, str) else str(final.content)
    return {"assistant": content}
