from langchain_openai import ChatOpenAI
from langchain_mcp_adapters.client import MultiServerMCPClient
from langgraph.prebuilt import create_react_agent
from langgraph_supervisor import create_supervisor
from langchain_core.messages import HumanMessage, AIMessage
from langchain_core.tools import tool
from langchain_core.prompts import ChatPromptTemplate
from typing import Any, Dict, List
from dotenv import load_dotenv
import os
from app.agents.prompts import (
    GOALS_AGENT_PROMPT,
    SUPERVISOR_PROMPT,
    DIET_AGENT_PROMPT,
    STRENGTH_AGENT_PROMPT,
    CARDIO_AGENT_PROMPT,
)
from app.agents.context import CURRENT_JWT, CURRENT_GOAL_ID
from app.tools.goals_mcp import make_goals_mcp_tools
from app.tools.generators import make_generators
from app.tools.search_tavily import get_tavily_tool
from app.agents.utils.tracing import TracingCallbackHandler
from app.agents.schemas import ItemsModel

# Load environment variables from .env file
load_dotenv()

# --- Configuration ---
# IMPORTANT: Make sure your .env file has SUPABASE_PAT defined.
SUPABASE_ACCESS_TOKEN = os.getenv("SUPABASE_PAT")
SUPABASE_PROJECT_ID = os.getenv("SUPABASE_PROJECT_ID")  # optional but recommended
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")
TAVILY_API_KEY = os.getenv("TAVILY_API_KEY")

## context variables are imported from app.agents.context
class FitnessCoach:
    def __init__(self):
        # Initialize MCP client to run your servers locally
        self.mcp_client = MultiServerMCPClient({
            "supabase": {
                "command": "npx",
                "args": [
                    "-y",
                    "@supabase/mcp-server-supabase@latest",
                    "--project-ref=tqbtufjwjcsgnhoopiyx"
                ],
                "env": {
                    "SUPABASE_ACCESS_TOKEN": SUPABASE_ACCESS_TOKEN
                },
                "transport": "stdio",
            },
            "goals": {
                "command": "python",
                "args": ["-m", "app.mcp.goals_server"],  # moved to app/mcp/goals_server.py
                "env": {
                    "SUPABASE_URL": os.getenv("SUPABASE_URL", ""),
                    "SUPABASE_ANON_KEY": os.getenv("SUPABASE_ANON_KEY", ""),
                },
                "transport": "stdio",
            },
            # "tavily": {
            #     # Use Tavily's hosted MCP via SSE transport
            #     "transport": "sse",
            #     "url": f"https://mcp.tavily.com/mcp/?tavilyApiKey={TAVILY_API_KEY}",
            # },
        })
        # Shared tracer across the whole graph so we can see cross-agent flow
        self.tracer = TracingCallbackHandler()
        self.supervisor = None  # This will hold the compiled, runnable agent
        self.goals_agent = None  # expose for direct invocation
        self.graph = None # This will hold the uncompiled graph for plotting 

    async def setup_agents(self):
        # Retrieve MCP tools from the "goals" server (no explicit client start needed)
        goals_tools = await self.mcp_client.get_tools(server_name="goals")
        # Tavily is wired via LangChain tool (not MCP) for reliability
        tavily_tool = get_tavily_tool(max_results=5)
        # Map tool name -> tool instance for direct invocation
        goals_tool_map = {
            (getattr(t, "name", None) or getattr(t, "lc_name", None) or ""): t
            for t in goals_tools
        }
        # MCP Goals server tool wrappers (injects JWT/goal_id)
        mcp_get_goals, mcp_get_goal_tasks = make_goals_mcp_tools(goals_tool_map)
        
        # Domain sub-agents as ReAct agents (no tools initially). You can add per-agent tools later.
        diet_agent = create_react_agent(
            model=ChatOpenAI(model="gpt-5-mini", temperature=0, callbacks=[self.tracer]),
            tools=[],
            name="diet_agent",
            prompt=DIET_AGENT_PROMPT,
        )
        strength_agent = create_react_agent(
            model=ChatOpenAI(model="gpt-5-mini", temperature=0, callbacks=[self.tracer]),
            tools=[],
            name="strength_agent",
            prompt=STRENGTH_AGENT_PROMPT,
        )
        cardio_agent = create_react_agent(
            model=ChatOpenAI(model="gpt-5-mini", temperature=0, callbacks=[self.tracer]),
            tools=[],
            name="cardio_agent",
            prompt=CARDIO_AGENT_PROMPT,
        )

        # Expose domain agents on self for direct server-side calls
        try:
            self.diet_agent = diet_agent.compile() if hasattr(diet_agent, "compile") else diet_agent
        except Exception:
            self.diet_agent = diet_agent
        try:
            self.strength_agent = strength_agent.compile() if hasattr(strength_agent, "compile") else strength_agent
        except Exception:
            self.strength_agent = strength_agent
        try:
            self.cardio_agent = cardio_agent.compile() if hasattr(cardio_agent, "compile") else cardio_agent
        except Exception:
            self.cardio_agent = cardio_agent

        # Parallel structured-output runnables for deterministic server path
        # Use a small, reliable model for structured outputs
        base_struct = ChatOpenAI(model="gpt-4o-mini", temperature=0, callbacks=[self.tracer])
        diet_model = base_struct.with_structured_output(ItemsModel)
        strength_model = base_struct.with_structured_output(ItemsModel)
        cardio_model = base_struct.with_structured_output(ItemsModel)

        diet_prompt = ChatPromptTemplate.from_messages([
            ("system", DIET_AGENT_PROMPT),
            ("human", "CONTEXT:\n{context_json}")
        ])
        strength_prompt = ChatPromptTemplate.from_messages([
            ("system", STRENGTH_AGENT_PROMPT),
            ("human", "CONTEXT:\n{context_json}")
        ])
        cardio_prompt = ChatPromptTemplate.from_messages([
            ("system", CARDIO_AGENT_PROMPT),
            ("human", "CONTEXT:\n{context_json}")
        ])

        self.diet_struct = diet_prompt | diet_model
        self.strength_struct = strength_prompt | strength_model
        self.cardio_struct = cardio_prompt | cardio_model

        # Expose MCP goals tools via factory wrappers
        # mcp_get_goals, mcp_get_goal_tasks are now LangChain tools

        # Domain generators via factory; each returns a tool producing {"items": [...]}
        diet_generate, strength_generate, cardio_generate = make_generators(
            diet_agent, strength_agent, cardio_agent, self.tracer
        )

        # NOW create the goals coordinator agent with domain tools attached
        goals_agent = create_react_agent(
            model=ChatOpenAI(model="gpt-5-mini", temperature=0, callbacks=[self.tracer]),
            tools=[diet_generate, strength_generate, cardio_generate],
            name="goals_agent",
            prompt=GOALS_AGENT_PROMPT,
        )

        # Supervisor doesn't need domain tools; keep only MCP reads here
        adapted_goals_tools = [mcp_get_goals, mcp_get_goal_tasks, tavily_tool]

        supervisor = create_supervisor(
            agents=[goals_agent],
            tools=adapted_goals_tools,
            model=ChatOpenAI(model="gpt-4o", callbacks=[self.tracer]),
            prompt=SUPERVISOR_PROMPT,
        )

        # compile the supervisor into a runnable
        compiled = supervisor.compile()
        self.supervisor = compiled
        # Store goals agent runnable for direct calls
        try:
            self.goals_agent = goals_agent.compile() if hasattr(goals_agent, "compile") else goals_agent
        except Exception:
            self.goals_agent = goals_agent

    async def generate_tasks_direct(self, user_profile: dict, goal: dict, existing_tasks_summary: dict | None = None) -> dict:
        """Deterministically call domain sub-agents based on goal.type and merge outputs.

        Returns a dict: {"items": [ ... ]}
        """
        payload = {"user_profile": user_profile, "goal": goal, "existing_tasks_summary": existing_tasks_summary or None}

        # Map goal types to which domain sub-agents to call (primary) with structured fallback
        goal_type = (goal.get("type") or "").lower()
        agents_to_call = []
        fallback_struct = []
        if goal_type in {"fat_loss"}:
            agents_to_call = [self.diet_agent, self.cardio_agent]
            # fallback_struct = [self.diet_struct, self.cardio_struct]
        elif goal_type in {"build_muscle"}:
            agents_to_call = [self.strength_agent, self.diet_agent, self.cardio_agent]
            # fallback_struct = [self.strength_struct, self.diet_struct, self.cardio_struct]
        elif goal_type in {"healthy_lifestyle"}:
            agents_to_call = [self.diet_agent]
            # fallback_struct = [self.diet_struct]
        elif goal_type in {"sculpt_flow"}:
            agents_to_call = [self.strength_agent, self.cardio_agent, self.diet_agent]
            # fallback_struct = [self.strength_struct, self.cardio_struct, self.diet_struct]
        else:
            # default: try all three
            agents_to_call = [self.diet_agent, self.strength_agent, self.cardio_agent]
            # fallback_struct = [self.diet_struct, self.strength_struct, self.cardio_struct]

        # Run calls in parallel for speed
        merged: list[dict] = []
        import json as _json
        import re as _re
        import asyncio as _asyncio
        def _extract_json_dict(text: str) -> Dict[str, Any]:
            s = text.strip()
            # direct parse
            try:
                obj = _json.loads(s)
                if isinstance(obj, dict):
                    return obj
            except Exception:
                pass
            # fenced
            fence = _re.search(r"```json\s*(\{[\s\S]*?\})\s*```", s) or _re.search(r"```\s*(\{[\s\S]*?\})\s*```", s)
            if fence:
                try:
                    obj = _json.loads(fence.group(1))
                    if isinstance(obj, dict):
                        return obj
                except Exception:
                    pass
            # braces slice
            if "{" in s and "}" in s:
                try:
                    start = s.find("{")
                    end = s.rfind("}") + 1
                    obj = _json.loads(s[start:end])
                    if isinstance(obj, dict):
                        return obj
                except Exception:
                    pass
            return {"items": []}
        def _norm(res: Any) -> Dict[str, Any]:
            if isinstance(res, dict):
                # LangGraph compiled agents often return {"messages": [...]}
                msgs = res.get("messages") if isinstance(res, dict) else None
                if isinstance(msgs, list) and msgs:
                    # find last AI-like message
                    from langchain_core.messages import AIMessage as _AI
                    last_ai = next((m for m in reversed(msgs) if isinstance(m, _AI)), None)
                    if last_ai and isinstance(getattr(last_ai, "content", None), str):
                        return _extract_json_dict(last_ai.content)  # type: ignore[attr-defined]
                return res
            if hasattr(res, "model_dump"):
                try:
                    return res.model_dump()  # type: ignore
                except Exception:
                    pass
            if isinstance(res, AIMessage):
                content = getattr(res, "content", None)
                if isinstance(content, str):
                    return _extract_json_dict(content)
                return {"items": []}
            if isinstance(res, str):
                return _extract_json_dict(res)
            return {"items": []}

        async def _call_agent(idx: int, ag):
            ctx = _json.dumps(payload, default=str)
            ag_name = getattr(ag, 'name', None) or getattr(getattr(ag, 'config', None), 'name', None) or f"agent_{idx}"
            print(f"[DEBUG] direct_generate calling subagent={ag_name} goal_type={goal_type}")
            try:
                res = await ag.ainvoke({"messages": [HumanMessage(content=f"CONTEXT:\n{ctx}")]}, config={"callbacks": [self.tracer]})
            except Exception:
                res = await ag.ainvoke({"context_json": ctx}, config={"callbacks": [self.tracer]})
            out = _norm(res)
            items = out.get("items", []) if isinstance(out, dict) else []
            count = len(items) if isinstance(items, list) else 0
            if count == 0:
                raw = getattr(res, "content", None) if isinstance(res, AIMessage) else (res if isinstance(res, str) else None)
                snippet = (raw[:300] + "…") if isinstance(raw, str) and len(raw) > 300 else (raw or "<non-text>")
                print(f"[DEBUG] subagent={ag_name} returned 0 items; raw= {snippet}")
            else:
                print(f"[DEBUG] subagent={ag_name} produced {count} items")
            return items

        results = await _asyncio.gather(*(_call_agent(i, ag) for i, ag in enumerate(agents_to_call)))
        for items in results:
            merged.extend(items or [])

        # Optional: light dedupe by (title, due_at)
        seen = set()
        deduped = []
        for it in merged:
            key = (it.get("title"), it.get("due_at"))
            if key in seen:
                continue
            seen.add(key)
            deduped.append(it)

        return {"items": deduped}