from __future__ import annotations

from typing import Any, Dict, List, Optional

import os
from supabase import create_client
import httpx

_SUPABASE_URL = os.getenv("SUPABASE_URL", "")
_SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")

def _sb_headers(user_token: str) -> dict:
    return {
        "Authorization": f"Bearer {user_token}",
        "apikey": _SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

_HTTPX_TIMEOUT = httpx.Timeout(connect=10.0, read=20.0, write=10.0, pool=20.0)
def _sb_request(method: str, url: str, *, headers: dict, json: dict | None = None):
    with httpx.Client(timeout=_HTTPX_TIMEOUT) as client:
        return client.request(method, url, headers=headers, json=json)

from langchain_core.messages import (
    AIMessage,
    BaseMessage,
    HumanMessage,
    SystemMessage,
    ToolMessage,
)


def _get_supabase_keys() -> Dict[str, Optional[str]]:
    """Load Supabase credentials from env. Prefer service role, fallback to anon."""
    url = os.environ.get("SUPABASE_URL")
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    anon_key = os.environ.get("SUPABASE_ANON_KEY")
    key = service_key or anon_key
    if not url or not key:
        raise RuntimeError("Missing SUPABASE_URL or API key (SERVICE_ROLE_KEY/ANON_KEY)")
    return {"url": url, "key": key}


def _to_lc_message(role: str, content: Dict[str, Any]) -> BaseMessage:
    """Map DB (role, content) → LangChain message. For text, expect {"text": "..."}."""
    text = ""
    if isinstance(content, dict) and isinstance(content.get("text"), str):
        text = content["text"]

    if role == "user":
        return HumanMessage(content=text or content)
    if role == "assistant":
        return AIMessage(content=text or content)
    if role == "system":
        return SystemMessage(content=text or content)
    if role == "tool":
        tool_call_id = content.get("tool_call_id") if isinstance(content, dict) else None
        return ToolMessage(content=text or content, tool_call_id=tool_call_id)
    # Fallback to human
    return HumanMessage(content=text or content)


def _from_lc_message(msg: BaseMessage) -> Dict[str, Any]:
    """Map LangChain message → DB payload {role, content}.
    If content is str, store {"text": "..."} for readability.
    """
    role = "user"
    if isinstance(msg, AIMessage):
        role = "assistant"
    elif isinstance(msg, SystemMessage):
        role = "system"
    elif isinstance(msg, ToolMessage):
        role = "tool"

    if isinstance(msg.content, str):
        content: Dict[str, Any] = {"text": msg.content}
    else:
        # Structured content: store as-is
        content = msg.content  # type: ignore[assignment]
    return {"role": role, "content": content}


class ChatStore:
    """DB-backed transcript store for conversations/messages.

    Expected schema:
      conversations(id uuid pk, user_id uuid, goal_id uuid null, created_at timestamptz)
      messages(id uuid pk, conversation_id uuid fk, role text, content jsonb, created_at timestamptz)
    """

    def __init__(self, user_token: Optional[str] = None) -> None:
        # If a user token is provided, prefer REST with RLS
        self._user_token = user_token
        if user_token:
            # REST mode: RLS enforced by Supabase using JWT
            self._use_rest = True
        else:
            # Fallback to existing client (may use service role)
            self._use_rest = False
            creds = _get_supabase_keys()
            self._supa = create_client(creds["url"], creds["key"]) 

    def _from_table(self, table: str):
        """Return a builder with select/insert support. Use .table(...) for compatibility."""
        return self._supa.table(table)

    def get_or_create_conversation(self, user_id: str, goal_id: Optional[str] = None) -> str:
        """Return an existing conversation id for (user_id, goal_id) or create one."""
        if self._use_rest:
            if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
                raise RuntimeError("Supabase not configured")
            # Try to find existing
            base = f"{_SUPABASE_URL}/rest/v1/conversations?select=id&user_id=eq.{user_id}"
            if goal_id is None:
                url = base + "&goal_id=is.null&order=created_at.desc&limit=1"
            else:
                url = base + f"&goal_id=eq.{goal_id}&order=created_at.desc&limit=1"
            resp = _sb_request("GET", url, headers=_sb_headers(self._user_token))
            if resp.status_code == 200:
                data = resp.json() or []
                if isinstance(data, list) and data:
                    return data[0]["id"]
            # Create new
            payload = {"user_id": user_id, "goal_id": goal_id}
            create_url = f"{_SUPABASE_URL}/rest/v1/conversations"
            resp2 = _sb_request("POST", create_url, headers=_sb_headers(self._user_token), json=payload)
            if resp2.status_code not in (200, 201):
                raise RuntimeError(f"Failed to create conversation: {resp2.status_code} {resp2.text}")
            data2 = resp2.json() or []
            if isinstance(data2, list) and data2:
                return data2[0]["id"]
            if isinstance(data2, dict):
                return data2.get("id")
            raise RuntimeError("Conversation create response unexpected")
        # fallback client path
        q = (
            self._from_table("conversations")
            .select("id")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(1)
        )
        if goal_id is None:
            if hasattr(q, "is_"):
                q = q.is_("goal_id", None)
            else:
                q = q.filter("goal_id", "is", None)
        else:
            q = q.eq("goal_id", goal_id)
        found = q.execute()
        data = found.data or []
        if data:
            return data[0]["id"]

        # Create new conversation
        payload = {"user_id": user_id, "goal_id": goal_id}
        ins = (
            self._from_table("conversations")
            .insert(payload)
            .execute()
        )
        ins_data = ins.data or {}
        if isinstance(ins_data, list) and ins_data:
            return ins_data[0]["id"]
        return ins_data["id"]

    def find_conversation(self, user_id: str, goal_id: Optional[str] = None) -> Optional[str]:
        """Return conversation id for (user_id, goal_id) if it exists; else None.
        Does not create new rows.
        """
        if self._use_rest:
            if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
                raise RuntimeError("Supabase not configured")
            base = f"{_SUPABASE_URL}/rest/v1/conversations?select=id&user_id=eq.{user_id}"
            url = base + ("&goal_id=is.null" if goal_id is None else f"&goal_id=eq.{goal_id}") + "&order=created_at.desc&limit=1"
            resp = _sb_request("GET", url, headers=_sb_headers(self._user_token))
            if resp.status_code != 200:
                raise RuntimeError(f"Failed to find conversation: {resp.status_code} {resp.text}")
            data = resp.json() or []
            if isinstance(data, list) and data:
                return data[0].get("id")
            if isinstance(data, dict):
                return data.get("id")
            return None
        q = (
            self._from_table("conversations").select("id").eq("user_id", user_id).order("created_at", desc=True).limit(1)
        )
        if goal_id is None:
            if hasattr(q, "is_"):
                q = q.is_("goal_id", None)
            else:
                q = q.filter("goal_id", "is", None)
        else:
            q = q.eq("goal_id", goal_id)
        res = q.execute()
        data = res.data or []
        if isinstance(data, list) and data:
            return data[0].get("id")
        if isinstance(data, dict):
            return data.get("id")
        return None

    def fetch_recent_messages(self, conversation_id: str, limit_n: int = 30) -> List[Dict[str, Any]]:
        """Return latest N messages for a conversation in chronological order."""
        if self._use_rest:
            if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
                raise RuntimeError("Supabase not configured")
            url = (
                f"{_SUPABASE_URL}/rest/v1/messages?select=*&conversation_id=eq.{conversation_id}"
                f"&order=created_at.desc&limit={limit_n}"
            )
            resp = _sb_request("GET", url, headers=_sb_headers(self._user_token))
            if resp.status_code != 200:
                raise RuntimeError(f"Failed to fetch messages: {resp.status_code} {resp.text}")
            rows = resp.json() or []
            rows.reverse()
            return rows
        resp = (
            self._from_table("messages")
            .select("*")
            .eq("conversation_id", conversation_id)
            .order("created_at", desc=True)
            .limit(limit_n)
            .execute()
        )
        rows = resp.data or []
        rows.reverse()  # chronological
        return rows

    def fetch_messages_asc(self, conversation_id: str, limit_n: int = 200) -> List[Dict[str, Any]]:
        """Return messages oldest→newest for display."""
        if self._use_rest:
            if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
                raise RuntimeError("Supabase not configured")
            url = (
                f"{_SUPABASE_URL}/rest/v1/messages?select=*&conversation_id=eq.{conversation_id}"
                f"&order=created_at.asc&limit={limit_n}"
            )
            resp = _sb_request("GET", url, headers=_sb_headers(self._user_token))
            if resp.status_code != 200:
                raise RuntimeError(f"Failed to fetch messages: {resp.status_code} {resp.text}")
            return resp.json() or []
        resp = (
            self._from_table("messages")
            .select("*")
            .eq("conversation_id", conversation_id)
            .order("created_at", desc=False)
            .limit(limit_n)
            .execute()
        )
        rows = resp.data or []
        return rows

    def insert_message(self, conversation_id: str, role: str, content: Dict[str, Any]) -> Dict[str, Any]:
        payload = {"conversation_id": conversation_id, "role": role, "content": content}
        if self._use_rest:
            if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
                raise RuntimeError("Supabase not configured")
            url = f"{_SUPABASE_URL}/rest/v1/messages"
            resp = _sb_request("POST", url, headers=_sb_headers(self._user_token), json=payload)
            if resp.status_code not in (200, 201):
                raise RuntimeError(f"Failed to insert message: {resp.status_code} {resp.text}")
            data = resp.json() or []
            if isinstance(data, list) and data:
                return data[0]
            if isinstance(data, dict):
                return data
            return {}
        resp = self._from_table("messages").insert(payload).execute()
        data = resp.data or []
        if isinstance(data, list) and data:
            return data[0]
        if isinstance(data, dict):
            return data
        return {}

    def insert_lc_message(self, conversation_id: str, msg: BaseMessage) -> Dict[str, Any]:
        mapped = _from_lc_message(msg)
        return self.insert_message(conversation_id, mapped["role"], mapped["content"])

    def to_lc_messages(self, rows: List[Dict[str, Any]]) -> List[BaseMessage]:
        out: List[BaseMessage] = []
        for r in rows:
            role = r.get("role")
            content = r.get("content", {})
            out.append(_to_lc_message(role, content))
        return out