# app/tools/generators.py
from langchain_core.tools import tool
from langchain_core.messages import HumanMessage, AIMessage
from app.agents.schemas import ItemsModel


def _extract_json_dict(text: str) -> dict:
    """Try to extract a JSON object from arbitrary text.

    Handles cases where the model wraps JSON in code fences or includes prose.
    Returns {"items": []} on failure.
    """
    import json as _json
    import re as _re
    s = text.strip()
    # Try direct parse first
    try:
        obj = _json.loads(s)
        if isinstance(obj, dict):
            return obj
    except Exception:
        pass
    # Try fenced block ```json ... ``` or ``` ... ```
    fence = _re.search(r"```json\s*(\{[\s\S]*?\})\s*```", s)
    if not fence:
        fence = _re.search(r"```\s*(\{[\s\S]*?\})\s*```", s)
    if fence:
        try:
            obj = _json.loads(fence.group(1))
            if isinstance(obj, dict):
                return obj
        except Exception:
            pass
    # Try to locate a JSON object by finding the first '{' and last '}'
    if "{" in s and "}" in s:
        start = s.find("{")
        end = s.rfind("}") + 1
        candidate = s[start:end]
        try:
            obj = _json.loads(candidate)
            if isinstance(obj, dict):
                return obj
        except Exception:
            pass
    return {"items": []}


def _normalize_output(res) -> dict:
    """Normalize outputs from sub-agents to a dict with key 'items'.

    Supports dict, pydantic model, AIMessage (JSON text), or string JSON.
    """
    import json as _json
    if isinstance(res, dict):
        return res
    if hasattr(res, "model_dump"):
        try:
            return res.model_dump()
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


def make_generators(diet_agent, strength_agent, cardio_agent, tracer):
    @tool("diet_generate")
    async def diet_generate(user_profile: dict, goal: dict, existing_tasks_summary: dict | None = None) -> dict:
        """Generate diet/nutrition tasks. Inputs: user_profile, goal, existing_tasks_summary? -> {items}. Returns a JSON dict with key 'items'."""
        import json as _json
        payload = {"user_profile": user_profile, "goal": goal, "existing_tasks_summary": existing_tasks_summary or None}
        ctx = _json.dumps(payload, default=str)
        # ReAct sub-agent invocation via messages; fallback to legacy context_json
        try:
            res = await diet_agent.ainvoke({"messages": [HumanMessage(content=f"CONTEXT:\n{ctx}")]}, config={"callbacks": [tracer]})
        except Exception:
            res = await diet_agent.ainvoke({"context_json": ctx}, config={"callbacks": [tracer]})
        out = _normalize_output(res)
        try:
            model = ItemsModel.model_validate(out)
            out = model.model_dump()
        except Exception:
            out = {"items": []}
        if not isinstance(out, dict) or not out.get("items"):
            raw = getattr(res, "content", None) if isinstance(res, AIMessage) else (res if isinstance(res, str) else None)
            snippet = (raw[:300] + "…") if isinstance(raw, str) and len(raw) > 300 else (raw or "<non-text>")
            print(f"[DEBUG] diet_generate empty items; raw= {snippet}")
        return out

    @tool("strength_generate")
    async def strength_generate(user_profile: dict, goal: dict, existing_tasks_summary: dict | None = None) -> dict:
        """Generate strength/resistance training tasks. Inputs: user_profile, goal, existing_tasks_summary? -> {items}. Returns a JSON dict with key 'items'."""
        import json as _json
        payload = {"user_profile": user_profile, "goal": goal, "existing_tasks_summary": existing_tasks_summary or None}
        ctx = _json.dumps(payload, default=str)
        try:
            res = await strength_agent.ainvoke({"messages": [HumanMessage(content=f"CONTEXT:\n{ctx}")]}, config={"callbacks": [tracer]})
        except Exception:
            res = await strength_agent.ainvoke({"context_json": ctx}, config={"callbacks": [tracer]})
        out = _normalize_output(res)
        try:
            model = ItemsModel.model_validate(out)
            out = model.model_dump()
        except Exception:
            out = {"items": []}
        if not isinstance(out, dict) or not out.get("items"):
            raw = getattr(res, "content", None) if isinstance(res, AIMessage) else (res if isinstance(res, str) else None)
            snippet = (raw[:300] + "…") if isinstance(raw, str) and len(raw) > 300 else (raw or "<non-text>")
            print(f"[DEBUG] strength_generate empty items; raw= {snippet}")
        return out

    @tool("cardio_generate")
    async def cardio_generate(user_profile: dict, goal: dict, existing_tasks_summary: dict | None = None) -> dict:
        """Generate cardio tasks. Inputs: user_profile, goal, existing_tasks_summary? -> {items}. Returns a JSON dict with key 'items'."""
        import json as _json
        payload = {"user_profile": user_profile, "goal": goal, "existing_tasks_summary": existing_tasks_summary or None}
        ctx = _json.dumps(payload, default=str)
        try:
            res = await cardio_agent.ainvoke({"messages": [HumanMessage(content=f"CONTEXT:\n{ctx}")]}, config={"callbacks": [tracer]})
        except Exception:
            res = await cardio_agent.ainvoke({"context_json": ctx}, config={"callbacks": [tracer]})
        out = _normalize_output(res)
        try:
            model = ItemsModel.model_validate(out)
            out = model.model_dump()
        except Exception:
            out = {"items": []}
        if not isinstance(out, dict) or not out.get("items"):
            raw = getattr(res, "content", None) if isinstance(res, AIMessage) else (res if isinstance(res, str) else None)
            snippet = (raw[:300] + "…") if isinstance(raw, str) and len(raw) > 300 else (raw or "<non-text>")
            print(f"[DEBUG] cardio_generate empty items; raw= {snippet}")
        return out

    return diet_generate, strength_generate, cardio_generate
