from fastapi import HTTPException
from vitap_vtop_client.exceptions import (
    VitapVtopClientError,
    VtopSessionError,
    VtopLoginError,
    VtopLoginOtpRequiredError,
    VtopCsrfError,
)


def handle_client_exception(e: VitapVtopClientError):
    msg = str(e)
    lower_msg = msg.lower()
    # If the session is unauthenticated, expired, or awaiting OTP, return 401 Unauthorized
    if (
        isinstance(e, (VtopSessionError, VtopLoginError, VtopLoginOtpRequiredError, VtopCsrfError))
        or "awaiting otp" in lower_msg
        or "verify_login_otp" in lower_msg
        or "not logged in" in lower_msg
        or "session expired" in lower_msg
        or "session not found" in lower_msg
        or "unauthorized" in lower_msg
        or "authorizedidx" in lower_msg
    ):
        raise HTTPException(
            status_code=401,
            detail="VTOP session requires OTP verification or has expired. Please verify OTP or login again.",
        )
    status_code = e.status_code if e.status_code is not None else 400
    raise HTTPException(status_code=status_code, detail=msg)

