"""
OTP-aware VTOP session management.

Flow:

    POST /auth/login
        ↓
    creates ONE VtopClient
        ↓
    if OTP required:
        store the client + return session_id
        ↓
    POST /auth/verify_otp
        ↓
    verifies OTP using SAME VtopClient
        ↓
    authenticated VtopClient stays in session store
        ↓
    /student/* requests use that SAME VtopClient
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
# SESSION STORE
# ============================================================

# session_id -> VtopClient
#
# IMPORTANT:
# The VtopClient remains alive after /auth/login.
# This preserves the VTOP cookies/session required after OTP.
#
_session_store: dict[str, VtopClient] = {}

_session_created_at: dict[str, float] = {}

_session_lock = asyncio.Lock()

# Keep authenticated VTOP sessions for 12 hours.
# Change this if you want a shorter lifetime.
SESSION_TTL_SECONDS = 12 * 60 * 60


async def get_client_for_session(session_id: str) -> VtopClient:
    """
    Returns the existing authenticated/pending VtopClient.

    This function MUST be used by /student/* endpoints.

    It does NOT create a new VtopClient.
    """

    async with _session_lock:
        client = _session_store.get(session_id)
        created_at = _session_created_at.get(session_id)

    if client is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="VTOP session not found. Please login again.",
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


async def release_session(session_id: str) -> None:
    """
    Completely remove and close a VTOP session.
    """

    async with _session_lock:
        client = _session_store.pop(session_id, None)
        _session_created_at.pop(session_id, None)

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
    FastAPI dependency used by every /student/* endpoint.

    Flutter sends:

        X-VTOP-Session-ID: <session_id>

    We then retrieve the SAME VtopClient created during /auth/login.
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


# ============================================================
# LOGIN
# ============================================================

@router.post(
    "/login",
    response_model=LoginResponse,
)
async def login(request: LoginRequest):
    """
    Creates exactly ONE VtopClient.

    If VTOP requires OTP, the client remains alive in the
    session store until /auth/verify_otp is called.
    """

    session_id = str(uuid.uuid4())

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

        return LoginResponse(
            session_id=session_id,
            otp_required=False,
            message="Login successful.",
        )

    except VtopLoginOtpRequiredError:

        # VERY IMPORTANT:
        #
        # Do NOT close this client.
        #
        # It contains the VTOP session/cookies required
        # to verify the OTP later.
        #
        async with _session_lock:
            _session_store[session_id] = client
            _session_created_at[session_id] = time.time()

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
    Verifies OTP using the EXACT SAME VtopClient that was created
    during /auth/login.
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