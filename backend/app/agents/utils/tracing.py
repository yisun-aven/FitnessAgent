from typing import Any, Dict, List
from langchain_core.callbacks import BaseCallbackHandler

class TracingCallbackHandler(BaseCallbackHandler):
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
        label = payload.get("name") or payload.get("tool") or payload.get("lc_serializable")
        print(f"[TRACE] {kind}: {label}")

    def on_chain_start(self, serialized, inputs, **kwargs):
        name = self._label_from_serialized(serialized)
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

    def on_llm_start(self, serialized, prompts, **kwargs):
        name = self._label_from_serialized(serialized)
        safe_prompts = [self._truncate(p) for p in (prompts or [])]
        self._log("llm_start", {"name": name, "prompts": safe_prompts})

    def on_llm_end(self, response, **kwargs):
        texts: List[str] = []
        try:
            gens = getattr(response, "generations", []) or []
            for gen_list in gens:
                for gen in gen_list:
                    txt = getattr(getattr(gen, "message", None), "content", None) or getattr(gen, "text", None)
                    if txt:
                        texts.append(self._truncate(txt))
        except Exception as e:
            texts.append(f"<parse_error {e}>")
        self._log("llm_end", {"response": texts})

    def on_tool_start(self, serialized, input_str, **kwargs):
        try:
            name = serialized.get("name") if isinstance(serialized, dict) else self._label_from_serialized(serialized)
        except Exception:
            name = self._label_from_serialized(serialized)
        self._log("tool_start", {"tool": name, "input": self._truncate(input_str)})

    def on_tool_end(self, output, **kwargs):
        self._log("tool_end", {"output": self._truncate(output)})