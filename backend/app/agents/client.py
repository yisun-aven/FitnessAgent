from langchain_openai import ChatOpenAI
from langchain_mcp_adapters.client import MultiServerMCPClient
from langgraph.prebuilt import create_react_agent, ToolNode
from langgraph_supervisor import create_supervisor
from langchain_core.messages import HumanMessage, AIMessage
from langchain_core.callbacks import BaseCallbackHandler
from typing import Any, Dict, List, Iterable
import asyncio 
from dotenv import load_dotenv
import os
from app.agents.prompts import SQL_AGENT_PROMPT, GOALS_AGENT_PROMPT, SUPERVISOR_PROMPT

# Load environment variables from .env file
load_dotenv()

# --- Configuration ---
# IMPORTANT: Make sure your .env file has SUPABASE_PAT defined.
SUPABASE_ACCESS_TOKEN = os.getenv("SUPABASE_PAT")
SUPABASE_PROJECT_ID = os.getenv("SUPABASE_PROJECT_ID")  # optional but recommended
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

class TracingCallbackHandler(BaseCallbackHandler):
    """Lightweight tracer that prints key steps and captures them in-memory.

    This logs chain/LLM/tool starts and ends with condensed inputs/outputs so you can
    observe routing decisions (e.g., when the SQL agent/tool is invoked) and payloads.
    """

    def __init__(self) -> None:
        self.events: List[Dict[str, Any]] = []

    def _truncate(self, s: Any, limit: int = 400) -> str:
        try:
            text = s if isinstance(s, str) else repr(s)
        except Exception:
            text = str(s)
        if len(text) > limit:
            return text[:limit] + "…"
        return text

    def _label_from_serialized(self, serialized: Any) -> str:
        # LangChain may pass dict, list path segments, or None
        if serialized is None:
            return "None"
        if isinstance(serialized, dict):
            for k in ("id", "name", "lc_serializable"):
                v = serialized.get(k)
                if v:
                    return self._truncate(v, 120)
            return self._truncate(serialized, 120)
        if isinstance(serialized, (list, tuple)):
            try:
                return ".".join(str(x) for x in serialized)
            except Exception:
                return self._truncate(serialized, 120)
        return self._truncate(serialized, 120)

    def _log(self, kind: str, payload: Dict[str, Any]) -> None:
        entry = {"type": kind, **payload}
        self.events.append(entry)
        # Print concise line to server console for quick inspection
        label = payload.get("name") or payload.get("tool") or payload.get("lc_serializable")
        print(f"[TRACE] {kind}: {label}")
        # For verbose debugging, uncomment:
        # print(json.dumps(entry, indent=2, default=str))

    # Chains / graphs
    def on_chain_start(self, serialized, inputs, **kwargs):
        name = self._label_from_serialized(serialized)
        # inputs can be dict, list/tuple, or other
        if isinstance(inputs, dict):
            safe_inputs = {k: self._truncate(v) for k, v in inputs.items()}
        elif isinstance(inputs, (list, tuple)):
            safe_inputs = {str(i): self._truncate(v) for i, v in enumerate(inputs)}
        else:
            safe_inputs = {"value": self._truncate(inputs)}
        self._log("chain_start", {"name": name, "inputs": safe_inputs})

    def on_chain_end(self, outputs, **kwargs):
        safe_outputs = outputs
        try:
            if isinstance(outputs, dict):
                safe_outputs = {k: self._truncate(v) for k, v in outputs.items()}
        except Exception:
            safe_outputs = self._truncate(outputs)
        self._log("chain_end", {"outputs": safe_outputs})

    # LLM calls
    def on_llm_start(self, serialized, prompts, **kwargs):
        name = self._label_from_serialized(serialized)
        safe_prompts = [self._truncate(p) for p in (prompts or [])]
        self._log("llm_start", {"name": name, "prompts": safe_prompts})

    def on_llm_end(self, response, **kwargs):
        # Extract text generations concisely
        texts: List[str] = []
        try:
            gens = getattr(response, "generations", []) or []
            for gen_list in gens:
                for gen in gen_list:
                    # LangChain message/text differences
                    txt = getattr(getattr(gen, "message", None), "content", None) or getattr(gen, "text", None)
                    if txt:
                        texts.append(self._truncate(txt))
        except Exception as e:
            texts.append(f"<parse_error {e}>")
        self._log("llm_end", {"response": texts})

    # Tools (e.g., MCP Supabase tools)
    def on_tool_start(self, serialized, input_str, **kwargs):
        name = None
        try:
            name = serialized.get("name") if isinstance(serialized, dict) else self._label_from_serialized(serialized)
        except Exception:
            name = self._label_from_serialized(serialized)
        self._log("tool_start", {"tool": name, "input": self._truncate(input_str)})

    def on_tool_end(self, output, **kwargs):
        self._log("tool_end", {"output": self._truncate(output)})

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
                "args": ["-m", "app.agents.server"],  # path/module to your server file
                "env": {
                    "SUPABASE_URL": os.getenv("SUPABASE_URL", ""),
                    "SUPABASE_ANON_KEY": os.getenv("SUPABASE_ANON_KEY", ""),
                    "SUPABASE_SERVICE_ROLE_KEY": os.getenv("SUPABASE_SERVICE_ROLE_KEY", ""),
                },
                "transport": "stdio",
            },
        })
        # Shared tracer across the whole graph so we can see cross-agent flow
        self.tracer = TracingCallbackHandler()
        self.supervisor = None  # This will hold the compiled, runnable agent
        self.goals_agent = None  # expose for direct invocation
        self.graph = None # This will hold the uncompiled graph for plotting 

    async def setup_agents(self):
        sql_tools = await self.mcp_client.get_tools(server_name="supabase")
        goals_tools = await self.mcp_client.get_tools(server_name="goals")

        # Create subagents
        # sql_agent = create_react_agent(
        #     model=ChatOpenAI(model="gpt-4o", callbacks=[self.tracer]),
        #     tools=sql_tools,
        #     name="supabase_agent",
        #     prompt=SQL_AGENT_PROMPT,
        # )

        goals_agent = create_react_agent(
            model=ChatOpenAI(model="gpt-4o", callbacks=[self.tracer]),
            tools=[],
            name="goals_agent",
            prompt=GOALS_AGENT_PROMPT,
        )

        supervisor = create_supervisor(
            agents=[goals_agent],
            tools=goals_tools,
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
        # Some implementations may not expose a `.graph` attribute
        self.graph = getattr(supervisor, "graph", None)