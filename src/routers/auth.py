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
# SESSION STORE (STRICTLY SCOPED PER SESSION_ID)
# ============================================================

# session_id -> VtopClient
_session_store: dict[str, VtopClient] = {}

# session_id -> creation timestamp
_session_created_at: dict[str, float] = {}

# session_id -> registration_number (upper-case)
_session_usernames: dict[str, str] = {}

_session_lock = asyncio.Lock()

# Keep authenticated VTOP sessions for 12 hours.
SESSION_TTL_SECONDS = 12 * 60 * 60


async def get_client_for_session(
    session_id: str,
    expected_username: Optional[str] = None,
) -> VtopClient:
    """
    Returns the existing authenticated/pending VtopClient.
    Validates ownership if expected_username is provided.
    """

    async with _session_lock:
        client = _session_store.get(session_id)
        created_at = _session_created_at.get(session_id)
        owner_username = _session_usernames.get(session_id)

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
        return _session_usernames.get(session_id)


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
    """

    session_id = str(uuid.uuid4())
    reg_no = request.registration_number.strip().upper()

    client = VtopClient(
        registration_number=request.registration_number,
        password=request.password,
    )

    try:
        await client.login()

        # Login succeeded without OTP.
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
    Verifies OTP using the EXACT SAME VtopClient created during /auth/login.
    """

    client = await get_client_for_session(request.session_id)

    try:
        await client.verify_login_otp(request.otp)

        # Refresh session timestamp after successful authentication.
        async with _session_lock:
            _session_created_at[request.session_id] = time.time()

        return VerifyOtpResponse(
            session_id=request.session_id,
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

    try:
        await client.resend_login_otp()
        return {
            "message": (
                "OTP resent. "
                "Check your registered email/mobile."
            )
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