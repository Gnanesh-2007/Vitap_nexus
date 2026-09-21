from typing import Optional

import re

from fastapi import (
    APIRouter,
    Depends,
    Header,
    HTTPException,
    Request,
    Response,
    status,
)

from fastapi.responses import RedirectResponse

from pydantic import BaseModel

from vitap_vtop_client.client import VtopClient
from vitap_vtop_client.exceptions import (
    VitapVtopClientError,
)

from src.routers.auth import (
    get_vtop_client_from_header,
    get_client_for_session,
)

from src.utils.handle_client_exception import (
    handle_client_exception,
)


# ============================================================
# ROUTER
# ============================================================

router = APIRouter(
    prefix="/vtop_proxy",
    tags=["vtop_proxy"],
)


# ============================================================
# VTOP BASE
# ============================================================

VTOP_BASE = "https://vtop.vitap.ac.in"


# ============================================================
# REQUEST MODEL
# ============================================================

class StartSessionRequest(BaseModel):
    registration_number: str
    password: str


# ============================================================
# HTML REWRITE
# ============================================================

def _rewrite_html(
    html: str,
    proxy_base: str,
) -> str:
    """
    Rewrite VTOP URLs so they continue going through our proxy.
    """

    # --------------------------------------------------------
    # 1. Inject base tag
    # --------------------------------------------------------

    base_tag = (
        f'<base href="{proxy_base}">'
    )

    if "<head>" in html:
        html = html.replace(
            "<head>",
            f"<head>{base_tag}",
            1,
        )

    elif "<HEAD>" in html:
        html = html.replace(
            "<HEAD>",
            f"<HEAD>{base_tag}",
            1,
        )

    else:
        html = base_tag + html

    # --------------------------------------------------------
    # 2. href/src/action
    # --------------------------------------------------------

    html = re.sub(
        r'(href|src|action)=(["\'])/vtop/',
        lambda match:
            f'{match.group(1)}='
            f'{match.group(2)}'
            f'{proxy_base}',
        html,
    )

    # --------------------------------------------------------
    # 3. Absolute VTOP URLs
    # --------------------------------------------------------

    html = html.replace(
        f'"{VTOP_BASE}/vtop/',
        f'"{proxy_base}',
    )

    html = html.replace(
        f"'{VTOP_BASE}/vtop/",
        f"'{proxy_base}",
    )

    # --------------------------------------------------------
    # 4. JavaScript strings
    # --------------------------------------------------------

    html = re.sub(
        r"(['\"])/vtop/",
        lambda match:
            f"{match.group(1)}"
            f"{proxy_base}",
        html,
    )

    # --------------------------------------------------------
    # 5. location.href / location
    # --------------------------------------------------------

    html = re.sub(
        r'(location(?:\.href)?\s*=\s*["\'])/vtop/',
        lambda match:
            f"{match.group(1)}"
            f"{proxy_base}",
        html,
    )

    # --------------------------------------------------------
    # 6. CSS url()
    # --------------------------------------------------------

    html = re.sub(
        r'url\(["\']?/vtop/',
        lambda match:
            f"url({proxy_base}",
        html,
    )

    return html


# ============================================================
# START PROXY SESSION
# ============================================================

@router.post(
    "/start_session"
)
async def start_proxy_session(
    request: StartSessionRequest,
    request_obj: Request,
    client: VtopClient = Depends(
        get_vtop_client_from_header
    ),
):
    """
    Starts a Direct VTOP proxy using the EXISTING
    authenticated VtopClient.

    IMPORTANT:

    This endpoint does NOT do:

        VtopClient(...)
        await client.login()

    Therefore it does NOT create another VTOP login
    or another OTP request.
    """

    # --------------------------------------------------------
    # Get existing session ID from header.
    # --------------------------------------------------------

    session_id = request_obj.headers.get(
        "X-VTOP-Session-ID"
    )

    if not session_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "Missing VTOP session. "
                "Please login again."
            ),
        )

    # --------------------------------------------------------
    # The dependency has already verified that this session
    # exists and returned the SAME VtopClient.
    #
    # `client` is intentionally unused here because the
    # dependency itself validates the session.
    # --------------------------------------------------------

    _ = client

    return {
        "session_id": session_id,
        "portal_path": (
            f"/vtop_proxy/session/"
            f"{session_id}/content"
        ),
    }


# ============================================================
# VTOP REVERSE PROXY
# ============================================================

@router.api_route(
    "/session/{session_id}/{path:path}",
    methods=[
        "GET",
        "POST",
        "PUT",
        "PATCH",
        "DELETE",
    ],
)
async def proxy_vtop(
    session_id: str,
    path: str,
    request: Request,
):
    """
    Reverse proxy for an authenticated VTOP session.

    The VtopClient is retrieved from auth.py's session store.

    A NEW VtopClient is NEVER created here.
    """

    # ========================================================
    # GET EXISTING SESSION
    # ========================================================

    client = await get_client_for_session(
        session_id
    )

    # --------------------------------------------------------
    # Get the underlying httpx AsyncClient.
    #
    # This client already contains the VTOP authentication
    # cookies from /auth/login and /auth/verify_otp.
    # --------------------------------------------------------

    http_client = client._client

    if http_client is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=(
                "VTOP client session is no longer "
                "available. Please login again."
            ),
        )

    # ========================================================
    # BUILD TARGET URL
    # ========================================================

    clean_path = path.lstrip("/")

    # Strip redundant prefixes from relative link navigation
    if clean_path.startswith("content/"):
        clean_path = clean_path[len("content/"):]
    if clean_path.startswith("vtop/"):
        clean_path = clean_path[len("vtop/"):]

    if not clean_path:
        clean_path = "content"

    target_url = f"{VTOP_BASE}/vtop/{clean_path}"

    # ========================================================
    # REQUEST DATA
    # ========================================================

    query_params = dict(
        request.query_params
    )

    method = request.method

    body = await request.body()

    # ========================================================
    # FORWARD HEADERS
    # ========================================================

    skip_headers = {
        "host",
        "content-length",
        "connection",
        "transfer-encoding",
        "cookie",
    }

    forward_headers = {
        key: value
        for key, value in request.headers.items()
        if key.lower()
        not in skip_headers
    }

    # --------------------------------------------------------
    # VTOP headers
    # --------------------------------------------------------

    forward_headers["Referer"] = (
        f"{VTOP_BASE}/vtop/content"
    )

    forward_headers["Origin"] = VTOP_BASE

    csrf_token = getattr(client, "csrf_token", "") or ""
    if csrf_token:
        forward_headers["X-CSRF-TOKEN"] = csrf_token

    # ========================================================
    # REQUEST UPSTREAM VTOP
    # ========================================================

    try:
        upstream = await http_client.request(
            method=method,
            url=target_url,
            params=(
                query_params
                if query_params
                else None
            ),
            content=(
                body
                if body
                else None
            ),
            headers=forward_headers,
            timeout=30.0,
            follow_redirects=False,
        )

    except Exception as e:
        raise HTTPException(
            status_code=502,
            detail=(
                "VTOP proxy upstream error: "
                f"{e}"
            ),
        )

    # ========================================================
    # REDIRECTS
    # ========================================================

    if upstream.status_code in (
        301,
        302,
        303,
        307,
        308,
    ):
        location = upstream.headers.get(
            "location",
            "",
        )

        # ----------------------------------------------------
        # /vtop/...
        # ----------------------------------------------------

        if location.startswith("/vtop/"):
            proxied_location = (
                f"/vtop_proxy/session/"
                f"{session_id}/"
                f"{location.lstrip('/')}"
            )

        # ----------------------------------------------------
        # Absolute VTOP URL
        # ----------------------------------------------------

        elif location.startswith(
            f"{VTOP_BASE}/vtop/"
        ):
            proxied_location = (
                f"/vtop_proxy/session/"
                f"{session_id}/"
                f"{location[len(VTOP_BASE) + 1:].lstrip('/')}"
            )

        else:
            proxied_location = location

        return RedirectResponse(
            url=proxied_location,
            status_code=upstream.status_code,
        )

    # ========================================================
    # RESPONSE HEADERS
    # ========================================================

    content_type = (
        upstream.headers.get(
            "content-type",
            "",
        )
    )

    blocked_headers = {
        "x-frame-options",
        "content-security-policy",
        "content-encoding",
        "content-length",
        "server",
        "transfer-encoding",
        "connection",
    }

    response_headers = {
        key: value
        for key, value in upstream.headers.items()
        if key.lower()
        not in blocked_headers
    }

    # ========================================================
    # PROXY BASE
    # ========================================================

    proxy_base = (
        f"/vtop_proxy/session/"
        f"{session_id}/"
    )

    # ========================================================
    # HTML
    # ========================================================

    if "text/html" in content_type:
        html = upstream.text

        html = _rewrite_html(
            html,
            proxy_base,
        )

        return Response(
            content=html.encode(
                "utf-8"
            ),
            status_code=upstream.status_code,
            media_type=(
                "text/html; charset=utf-8"
            ),
            headers=response_headers,
        )

    # ========================================================
    # JAVASCRIPT / JSON
    # ========================================================

    if (
        "javascript" in content_type
        or "application/json"
        in content_type
    ):
        js = upstream.text

        js = re.sub(
            r"(['\"])/vtop/",
            lambda match:
                f"{match.group(1)}"
                f"{proxy_base}",
            js,
        )

        js = js.replace(
            f'"{VTOP_BASE}/vtop/',
            f'"{proxy_base}',
        )

        js = js.replace(
            f"'{VTOP_BASE}/vtop/",
            f"'{proxy_base}",
        )

        return Response(
            content=js.encode(
                "utf-8"
            ),
            status_code=upstream.status_code,
            media_type=content_type,
            headers=response_headers,
        )

    # ========================================================
    # CSS
    # ========================================================

    if "text/css" in content_type:
        css = upstream.text

        css = re.sub(
            r'url\(["\']?/vtop/',
            lambda match:
                f"url({proxy_base}",
            css,
        )

        return Response(
            content=css.encode(
                "utf-8"
            ),
            status_code=upstream.status_code,
            media_type=content_type,
            headers=response_headers,
        )

    # ========================================================
    # BINARY / OTHER
    # ========================================================

    return Response(
        content=upstream.content,
        status_code=upstream.status_code,
        media_type=content_type,
        headers=response_headers,
    )