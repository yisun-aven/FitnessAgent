from fastapi import APIRouter, Depends, Header, HTTPException
import os
import httpx
from typing import Optional
from fastapi.encoders import jsonable_encoder
import asyncio

from app.dependencies.auth import get_current_user
from app.models.schemas import Profile, ProfileUpsert

router = APIRouter()

_SUPABASE_URL = os.getenv("SUPABASE_URL", "")
_SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY", "")

def _uid(user_obj) -> str:
    return user_obj.get("id")

def _sb_headers(user_token: str) -> dict:
    return {
        "Authorization": f"Bearer {user_token}",
        "apikey": _SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

# Slightly more forgiving timeouts and simple retry for transient network issues
_HTTPX_TIMEOUT = httpx.Timeout(connect=10.0, read=20.0, write=10.0, pool=20.0)

async def _sb_request_with_retry(method: str, url: str, *, headers: dict, json: dict | None = None, retries: int = 2):
    last_exc: Exception | None = None
    for attempt in range(retries + 1):
        try:
            async with httpx.AsyncClient(timeout=_HTTPX_TIMEOUT) as client:
                resp = await client.request(method, url, headers=headers, json=json)
            return resp
        except (httpx.ConnectTimeout, httpx.ReadTimeout, httpx.ConnectError) as e:
            last_exc = e
            if attempt < retries:
                await asyncio.sleep(0.5 * (2 ** attempt))
            else:
                raise

@router.get("/me", response_model=Optional[Profile])
async def get_my_profile(user_obj = Depends(get_current_user), authorization: str | None = Header(default=None)):
    if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]

    uid = _uid(user_obj)
    url = f"{_SUPABASE_URL}/rest/v1/profiles?select=*&id=eq.{uid}"
    resp = await _sb_request_with_retry("GET", url, headers=_sb_headers(token))
    if resp.status_code != 200:
        print(f"[profile.me] supabase error {resp.status_code}: {resp.text}")
        raise HTTPException(status_code=resp.status_code, detail="Failed to fetch profile")
    data = resp.json()
    if isinstance(data, list) and data:
        return data[0]
    return None


@router.post("", response_model=Profile)
async def upsert_profile(payload: ProfileUpsert, user_obj = Depends(get_current_user), authorization: str | None = Header(default=None)):
    if not _SUPABASE_URL or not _SUPABASE_ANON_KEY:
        raise HTTPException(status_code=500, detail="Supabase not configured")
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")
    token = authorization.split(" ", 1)[1]

    uid = _uid(user_obj)

    # Check if profile exists
    get_url = f"{_SUPABASE_URL}/rest/v1/profiles?select=id&id=eq.{uid}"
    get_resp = await _sb_request_with_retry("GET", get_url, headers=_sb_headers(token))
    if get_resp.status_code != 200:
        print(f"[profile.upsert] precheck error {get_resp.status_code}: {get_resp.text}")
        raise HTTPException(status_code=get_resp.status_code, detail="Failed to fetch profile")
    exists = False
    try:
        body = get_resp.json()
        exists = isinstance(body, list) and len(body) > 0
    except Exception:
        exists = False

    if exists:
        # Update existing row
        patch_url = f"{_SUPABASE_URL}/rest/v1/profiles?id=eq.{uid}"
        async with httpx.AsyncClient(timeout=10) as client:
            patch_resp = await client.patch(patch_url, headers=_sb_headers(token), json=jsonable_encoder(payload.dict(exclude_unset=True)))
        if patch_resp.status_code not in (200, 204):
            print(f"[profile.upsert] patch error {patch_resp.status_code}: {patch_resp.text}")
            raise HTTPException(status_code=patch_resp.status_code, detail="Failed to update profile")
        # fetch updated
        final = await _sb_request_with_retry("GET", f"{_SUPABASE_URL}/rest/v1/profiles?select=*&id=eq.{uid}", headers=_sb_headers(token))
        if final.status_code != 200:
            raise HTTPException(status_code=final.status_code, detail="Failed to read updated profile")
        data = final.json()
        return data[0] if isinstance(data, list) and data else data
    else:
        # Insert new row with id
        insert_payload = {"id": uid, **payload.dict(exclude_unset=True)}
        post_url = f"{_SUPABASE_URL}/rest/v1/profiles"
        async with httpx.AsyncClient(timeout=10) as client:
            post_resp = await client.post(post_url, headers=_sb_headers(token), json=jsonable_encoder(insert_payload))
        if post_resp.status_code not in (200, 201):
            print(f"[profile.upsert] insert error {post_resp.status_code}: {post_resp.text}")
            raise HTTPException(status_code=post_resp.status_code, detail="Failed to create profile")
        data = post_resp.json()
        if isinstance(data, list) and data:
            return data[0]
        return data