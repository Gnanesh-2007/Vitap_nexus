from fastapi import HTTPException
from vitap_vtop_client.exceptions import VitapVtopClientError


def handle_client_exception(e: VitapVtopClientError):
    msg = str(e)
    # If the session is unauthenticated or awaiting OTP, return 401 Unauthorized
    if "awaiting OTP" in msg or "verify_login_otp" in msg or "not logged in" in msg or "Session expired" in msg:
        raise HTTPException(
            status_code=401,
            detail="VTOP session requires OTP verification or has expired. Please verify OTP or login again.",
        )
    status_code = e.status_code if e.status_code is not None else 400
    raise HTTPException(status_code=status_code, detail=msg)
