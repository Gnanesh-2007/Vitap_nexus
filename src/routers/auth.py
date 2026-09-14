"""
OTP-aware session store and login endpoints.

Flow:
  1. Client POSTs /auth/login  → 200 {session_id, otp_required: false}  OR
                                  202 {session_id, otp_required: true}
  2. If otp_required, client POSTs /auth/verify_otp  → 200 {session_id, otp_required: false}
  3. Client passes session_id instead of credentials for /student/* calls
     (the session-aware endpoints pick up the live VtopClient from the store).
"""

import asyncio
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
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

# ---------------------------------------------------------------------------
# In-memory session store: session_id -> VtopClient
# Each client is kept alive (not closed) so that OTP state persists across
# the /login → /verify_otp → /student/* request chain.
# ---------------------------------------------------------------------------
_session_store: dict[str, VtopClient] = {}
_session_lock = asyncio.Lock()

SESSION_TTL_SECONDS = 600  # 10 minutes — clean up stale sessions


async def get_client_for_session(session_id: str) -> VtopClient:
    """Return the live VtopClient for a session, or 404 if not found."""
    client = _session_store.get(session_id)
    if client is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Session '{session_id}' not found. Please login again.",
        )
    return client


async def release_session(session_id: str) -> None:
    """Close and remove a session from the store."""
    async with _session_lock:
        client = _session_store.pop(session_id, None)
        if client:
            await client.close()


# ---------------------------------------------------------------------------
# Request / Response models
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/login", response_model=LoginResponse)
async def login(request: LoginRequest):
    """
    Initiates a VTOP login.

    - Returns 200 with otp_required=false when login succeeds immediately.
    - Returns 202 with otp_required=true when VTOP demands an OTP.
      Call /auth/verify_otp with the returned session_id to finish.
    """
    session_id = str(uuid.uuid4())
    client = VtopClient(
        registration_number=request.registration_number,
        password=request.password,
    )

    try:
        await client.login()
        # Login succeeded without OTP
        async with _session_lock:
            _session_store[session_id] = client

        return LoginResponse(
            session_id=session_id,
            otp_required=False,
            message="Login successful.",
        )

    except VtopLoginOtpRequiredError:
        # VTOP sent an OTP to the student's registered email/phone.
        # Keep the client alive so verify_login_otp can use its internal state.
        async with _session_lock:
            _session_store[session_id] = client

        return LoginResponse(
            session_id=session_id,
            otp_required=True,
            message="OTP sent to your registered email/mobile. Please verify.",
        )

    except VitapVtopClientError as e:
        await client.close()
        raise HTTPException(status_code=400, detail=str(e))

    except Exception as e:
        await client.close()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unexpected error during login: {e}",
        )


@router.post("/verify_otp", response_model=VerifyOtpResponse)
async def verify_otp(request: VerifyOtpRequest):
    """
    Completes a login that VTOP gated with an OTP challenge.

    Supply the session_id from /auth/login and the OTP the student received.
    """
    client = await get_client_for_session(request.session_id)

    try:
        await client.verify_login_otp(request.otp)
        return VerifyOtpResponse(
            session_id=request.session_id,
            otp_required=False,
            message="OTP verified. Login complete.",
        )

    except VtopLoginOtpIncorrectError:
        raise HTTPException(status_code=400, detail="Incorrect OTP. Please try again.")

    except VtopLoginOtpExpiredError:
        await release_session(request.session_id)
        raise HTTPException(
            status_code=400,
            detail="OTP has expired. Please login again.",
        )

    except (VtopSessionError, VitapVtopClientError) as e:
        raise HTTPException(status_code=400, detail=str(e))

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Unexpected error verifying OTP: {e}",
        )


@router.post("/resend_otp")
async def resend_otp(request: ResendOtpRequest):
    """Ask VTOP to resend the login OTP for the given session."""
    client = await get_client_for_session(request.session_id)
    try:
        await client.resend_login_otp()
        return {"message": "OTP resent. Check your registered email/mobile."}
    except VitapVtopClientError as e:
        raise HTTPException(status_code=400, detail=str(e))
