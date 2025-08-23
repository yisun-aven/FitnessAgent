import asyncio
from typing import Any, Dict, Optional, List

from langchain_core.messages import HumanMessage, AIMessage, BaseMessage

from app.agents.client import FitnessCoach
from app.dependencies.chat_store import ChatStore


class CoachService:
    def __init__(self) -> None:
        self._coach = FitnessCoach()
        self._ready = False
        self._ready_lock = asyncio.Lock()
        # In-memory per-user histories to preserve context (kept temporarily as fallback/cache)
        self._histories: Dict[str, List[BaseMessage]] = {}
        # DB-backed transcript store
        self._store = ChatStore()

    async def _ensure_ready(self) -> None:
        if self._ready:
            return
        async with self._ready_lock:
            if self._ready:
                return
            # initialize / compile supervisor graph
            await self._coach.setup_agents()
            self._ready = True

    async def ainvoke_chat(
        self,
        *,
        user_id: str,
        message: str,
        goal_id: Optional[str] = None,
    ) -> AIMessage:
        """Send a message to the supervisor agent and return the final AIMessage.

        The supervisor graph expects a list of LC messages under the `messages` key.
        We include user_id/goal_id inline to guide routing, but the Supervisor prompt
        determines the actual tool calls.
        """
        await self._ensure_ready()

        # Prepare annotated user content for routing transparency
        user_content = message
        

        # Resolve conversation for (user_id, goal_id); Home uses goal_id=None
        conversation_id = self._store.get_or_create_conversation(user_id, goal_id)

        # Load recent messages from DB and convert to LangChain messages
        recent_rows = self._store.fetch_recent_messages(conversation_id, limit_n=30)
        history: List[BaseMessage] = self._store.to_lc_messages(recent_rows)

        # Append and persist the new human message before invoking the model
        new_human = HumanMessage(content=user_content)
        input_messages: List[BaseMessage] = [*history, new_human]
        self._store.insert_message(conversation_id, role="user", content={"text": user_content})

        print(
            f"[DEBUG] invoking supervisor: user={user_id} history_len={len(history)} last_user={user_content[:120]}"
        )

        # Invoke the compiled supervisor with full history and our tracer callbacks
        result: Dict[str, Any] = await self._coach.supervisor.ainvoke(
            {"messages": input_messages},
            config={"callbacks": [self._coach.tracer]},
        )

        # LangGraph returns a dict with messages under the `messages` key; the last one
        # should be the AI's final message.
        msgs: list[BaseMessage] = result.get("messages", [])  # type: ignore

        # Print a concise transcript of agent conversation
        def _sender(m: BaseMessage) -> str:
            # Try several places where LangChain/LangGraph may stash the agent name
            for key in ("name",):
                val = getattr(m, key, None)
                if isinstance(val, str) and val:
                    return val
            ak = getattr(m, "additional_kwargs", None) or {}
            for key in ("name", "sender", "agent", "from"):
                val = ak.get(key)
                if isinstance(val, str) and val:
                    return val
            rm = getattr(m, "response_metadata", None) or {}
            val = rm.get("agent") if isinstance(rm, dict) else None
            if isinstance(val, str) and val:
                return val
            return "supervisor"

        def _role(m: BaseMessage) -> str:
            # Common message classes: HumanMessage/AIMessage/ToolMessage/SystemMessage
            r = getattr(m, "type", None) or m.__class__.__name__.replace("Message", "").lower()
            s = _sender(m)
            return f"{r}[{s}]"

        print("[TRANSCRIPT] ---- agent conversation start ----")
        for i, m in enumerate(msgs[-20:]):  # last 20 turns to keep it short
            content = getattr(m, "content", "")
            if not isinstance(content, str):
                try:
                    content = str(content)
                except Exception:
                    content = "<non-text>"
            content = content.replace("\n", " ")
            if len(content) > 300:
                content = content[:300] + "…"
            print(f"[TRANSCRIPT] {i:02d} { _role(m) }: {content}")
        print("[TRANSCRIPT] ---- agent conversation end ------")

        if not msgs:
            # Fall back: wrap an empty response
            return AIMessage(content="")
        # Find the last AI message
        last_ai = next((m for m in reversed(msgs) if isinstance(m, AIMessage)), None)

        # Persist assistant turn and return final message
        final_ai = last_ai or AIMessage(content=str(msgs[-1].content))
        self._store.insert_lc_message(conversation_id, final_ai)
        return final_ai

    def progress(self, goal_id: str) -> Dict[str, Any]:
        # Placeholder; you can wire this into Supabase via the sql_agent later
        return {"goal_id": goal_id, "status": "unknown", "note": "progress endpoint placeholder"}


# Singleton accessor used by FastAPI routes
_coach_singleton: Optional[CoachService] = None
_singleton_lock = asyncio.Lock()


async def get_coach() -> CoachService:
    global _coach_singleton
    if _coach_singleton is not None:
        return _coach_singleton
    async with _singleton_lock:
        if _coach_singleton is None:
            _coach_singleton = CoachService()
            await _coach_singleton._ensure_ready()
        return _coach_singleton
