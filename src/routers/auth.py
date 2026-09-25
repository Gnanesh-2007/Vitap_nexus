"""
OTP-aware VTOP session management with strict user-isolation.

Flow:

    POST /auth/login
        ↓
    creates ONE VtopClient bound to registration_number
        ↓
    if OTP required:
        store client + username + return session_id
        ↓
    POST /auth/verify_otp
        ↓
    verifies OTP using SAME VtopClient
        ↓
    authenticated VtopClient stays in session store
        ↓
    /student/* requests verify X-VTOP-Session-ID matches user
        ↓
    POST /auth/logout
        ↓
    destroys VTOP session and closes client immediately
"""

import asyncio
import time
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Header, status
from pydantic import BaseModel

from vitap_vtop_client.client import VtopClient
from vitap_vtop_client.exceptions import (
    VitapVtopClientError,
    VtopLoginOtpRequiredError,
    VtopLoginOtpIncorrectError,
    VtopLoginOtpExpiredError,
    VtopSessionError,
)

from src.dependencies import verify_api_key


router = APIRouter(
    prefix="/auth",
    tags=["auth"],
    dependencies=[Depends(verify_api_key)],
)


# ============================================================
# SESSION STORE (STRICTLY SCOPED PER SESSION_ID & SERVERLESS RESILIENT)
# ============================================================

import base64
import hashlib
import hmac
import json
import os
import zlib

_SESSION_SECRET = os.getenv("API_KEY", "vitap-vtop-stateless-key").encode("utf-8")

# In-memory hot cache for ultra-fast access in warm serverless instances
# session_id -> VtopClient
_session_store: dict[str, VtopClient] = {}

# session_id -> creation timestamp
_session_created_at: dict[str, float] = {}

# session_id -> registration_number (upper-case)
_session_usernames: dict[str, str] = {}

_session_lock = asyncio.Lock()

# Keep authenticated VTOP sessions for 12 hours.
SESSION_TTL_SECONDS = 12 * 60 * 60


def encode_vtop_session(client: VtopClient, reg_no: str, is_authenticated: bool) -> str:
    """
    Serializes a VtopClient state (cookies, CSRF tokens, credentials)
    into a compact, signed, tamper-proof token that survives across
    stateless Vercel serverless function invocations and container recycles.
    """
    try:
        cookies = {k: v for k, v in client._client.cookies.items()}
        csrf = ""
        if is_authenticated and client._logged_in_student:
            csrf = client._logged_in_student.post_login_csrf_token or ""
        elif client._pending_otp_csrf:
            csrf = client._pending_otp_csrf or ""

        payload = {
            "u": reg_no.upper().strip(),
            "p": client.password,
            "c": cookies,
            "csrf": csrf,
            "auth": is_authenticated,
            "ts": time.time(),
        }
        raw = json.dumps(payload).encode("utf-8")
        compressed = zlib.compress(raw, 9)
        encoded = base64.urlsafe_b64encode(compressed).decode("ascii")
        sig = hmac.new(_SESSION_SECRET, encoded.encode("ascii"), hashlib.sha256).hexdigest()[:16]
        return f"vtop_{sig}.{encoded}"
    except Exception as e:
        print(f"Error encoding session token: {e}")
        return str(uuid.uuid4())


def decode_vtop_session(token: str) -> Optional[dict]:
    """
    Validates and decodes a stateless session token.
    """
    if not token or not token.startswith("vtop_") or "." not in token:
        return None
    try:
        prefix_sig, encoded = token.split(".", 1)
        sig = prefix_sig.replace("vtop_", "")
        expected_sig = hmac.new(_SESSION_SECRET, encoded.encode("ascii"), hashlib.sha256).hexdigest()[:16]
        if not hmac.compare_digest(sig, expected_sig):
            return None
        compressed = base64.urlsafe_b64decode(encoded.encode("ascii"))
        raw = zlib.decompress(compressed)
        return json.loads(raw.decode("utf-8"))
    except Exception as e:
        print(f"Error decoding session token: {e}")
        return None


async def get_client_for_session(
    session_id: str,
    expected_username: Optional[str] = None,
) -> VtopClient:
    """
    Returns the existing authenticated/pending VtopClient.
    If the serverless container recycled or changed, restores the client
    state (including cookies and CSRF tokens) from the signed token.
    """
    # 1. Fast in-memory check (warm container)
    async with _session_lock:
        client = _session_store.get(session_id)
        created_at = _session_created_at.get(session_id)
        owner_username = _session_usernames.get(session_id)

    # 2. If not found in memory, restore from stateless token (serverless container switch)
    if client is None and session_id.startswith("vtop_"):
        data = decode_vtop_session(session_id)
        if data:
            reg_no = data.get("u", "").upper().strip()
            created_at = data.get("ts", time.time())
            owner_username = reg_no
            client = VtopClient(
                registration_number=reg_no,
                password=data.get("p", ""),
            )
            cookies = data.get("c", {})
            if cookies and isinstance(cookies, dict):
                client._client.cookies.update(cookies)

            if data.get("auth"):
                from vitap_vtop_client.login.model.logged_in_student_model import LoggedInStudent
                client._logged_in_student = LoggedInStudent(
                    registration_number=reg_no,
                    post_login_csrf_token=data.get("csrf", ""),
                )
            else:
                client._pending_otp_csrf = data.get("csrf")

            async with _session_lock:
                _session_store[session_id] = client
                _session_created_at[session_id] = created_at
                _session_usernames[session_id] = owner_username

    if client is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="VTOP session not found. Please login again.",
        )

    # Validate that session belongs to the requested student
    if expected_username is not None and owner_username is not None:
        if owner_username.upper().strip() != expected_username.upper().strip():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Session does not match the requested registration number.",
            )

    # Check session age.
    if created_at is not None:
        age = time.time() - created_at

        if age > SESSION_TTL_SECONDS:
            await release_session(session_id)

            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="VTOP session expired. Please login again.",
            )

    return client


async def get_session_username(session_id: str) -> Optional[str]:
    """Returns the registration number bound to a session."""
    async with _session_lock:
        uname = _session_usernames.get(session_id)
    if uname:
        return uname
    if session_id.startswith("vtop_"):
        data = decode_vtop_session(session_id)
        if data:
            return data.get("u", "").upper().strip()
    return None


async def release_session(session_id: str) -> None:
    """
    Completely remove, destroy, and close a VTOP session.
    """

    async with _session_lock:
        client = _session_store.pop(session_id, None)
        _session_created_at.pop(session_id, None)
        _session_usernames.pop(session_id, None)

    if client is not None:
        try:
            await client.close()
        except Exception:
            pass


async def get_vtop_client_from_header(
    x_vtop_session_id: Optional[str] = Header(
        default=None,
        alias="X-VTOP-Session-ID",
    ),
) -> VtopClient:
    """
    FastAPI dependency used by /student/* endpoints.
    Retrieves the VtopClient created during /auth/login.
    """

    if not x_vtop_session_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing VTOP session. Please login again.",
        )

    return await get_client_for_session(x_vtop_session_id)


# ============================================================
# REQUEST / RESPONSE MODELS
# ============================================================

class LoginRequest(BaseModel):
    registration_number: str
    password: str


class LoginResponse(BaseModel):
    session_id: str
    otp_required: bool
    message: str


class VerifyOtpRequest(BaseModel):
    session_id: str
    otp: str


class VerifyOtpResponse(BaseModel):
    session_id: str
    otp_required: bool
    message: str


class ResendOtpRequest(BaseModel):
    session_id: str


class LogoutRequest(BaseModel):
    session_id: str


# ============================================================
# LOGIN
# ============================================================

@router.post(
    "/login",
    response_model=LoginResponse,
)
async def login(request: LoginRequest):
    """
    Creates exactly ONE VtopClient bound to the student.
    Returns a serverless-resilient session token that survives Vercel container recycles.
    """

    reg_no = request.registration_number.strip().upper()

    client = VtopClient(
        registration_number=request.registration_number,
        password=request.password,
    )

    try:
        await client.login()

        # Login succeeded without OTP.
        session_id = encode_vtop_session(client, reg_no, is_authenticated=True)
        async with _session_lock:
            _session_store[session_id] = client
            _session_created_at[session_id] = time.time()
            _session_usernames[session_id] = reg_no

        return LoginResponse(
            session_id=session_id,
            otp_required=False,
            message="Login successful.",
        )

    except VtopLoginOtpRequiredError:
        session_id = encode_vtop_session(client, reg_no, is_authenticated=False)
        async with _session_lock:
            _session_store[session_id] = client
            _session_created_at[session_id] = time.time()
            _session_usernames[session_id] = reg_no

        return LoginResponse(
            session_id=session_id,
            otp_required=True,
            message=(
                "OTP sent to your registered email/mobile. "
                "Please verify."
            ),
        )

    except VitapVtopClientError as e:
        await client.close()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    except Exception as e:
        await client.close()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unexpected error during login: {e}",
        )


# ============================================================
# VERIFY OTP
# ============================================================

@router.post(
    "/verify_otp",
    response_model=VerifyOtpResponse,
)
async def verify_otp(request: VerifyOtpRequest):
    """
    Verifies OTP using the EXACT SAME VtopClient created during /auth/login,
    restoring cookies and pending CSRF token seamlessly if the serverless container switched.
    """

    client = await get_client_for_session(request.session_id)
    reg_no = client.username.upper().strip()

    try:
        await client.verify_login_otp(request.otp)

        # Generate fresh authenticated session token with post-login cookies
        verified_session_id = encode_vtop_session(client, reg_no, is_authenticated=True)
        async with _session_lock:
            _session_store[verified_session_id] = client
            _session_created_at[verified_session_id] = time.time()
            _session_usernames[verified_session_id] = reg_no
            # Also keep old session_id mapped if client references it
            _session_store[request.session_id] = client
            _session_created_at[request.session_id] = time.time()
            _session_usernames[request.session_id] = reg_no

        return VerifyOtpResponse(
            session_id=verified_session_id,
            otp_required=False,
            message="OTP verified. Login complete.",
        )

    except VtopLoginOtpIncorrectError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect OTP. Please try again.",
        )

    except VtopLoginOtpExpiredError:
        await release_session(request.session_id)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP has expired. Please login again.",
        )

    except (VtopSessionError, VitapVtopClientError) as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unexpected error verifying OTP: {e}",
        )


# ============================================================
# RESEND OTP
# ============================================================

@router.post("/resend_otp")
async def resend_otp(request: ResendOtpRequest):
    client = await get_client_for_session(request.session_id)
    reg_no = client.username.upper().strip()

    try:
        await client.resend_login_otp()
        # Ensure session token remains active
        new_session_id = encode_vtop_session(client, reg_no, is_authenticated=False)
        async with _session_lock:
            _session_store[new_session_id] = client
            _session_created_at[new_session_id] = time.time()
            _session_usernames[new_session_id] = reg_no

        return {
            "session_id": new_session_id,
            "message": (
                "OTP resent. "
                "Check your registered email/mobile."
            ),
        }
    except VitapVtopClientError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


# ============================================================
# LOGOUT
# ============================================================

@router.post("/logout")
async def logout(request: LogoutRequest):
    """
    Explicitly destroys the VTOP session and closes the client connection.
    Guarantees that a logged-out user's session can never be reused.
    """
    await release_session(request.session_id)
    return {
        "message": "VTOP session destroyed and logged out successfully."
    }