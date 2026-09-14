import uuid
from typing import Dict
from fastapi import APIRouter, Request, Response, HTTPException, status
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
from vitap_vtop_client.client import VtopClient
from vitap_vtop_client.exceptions import VitapVtopClientError
from src.utils.handle_client_exception import handle_client_exception

router = APIRouter(
    prefix="/vtop_proxy",
    tags=["vtop_proxy"],
)

VTOP_BASE = "https://vtop.vitap.ac.in"

# In-memory store of authenticated VTOP httpx clients by session ID
_active_clients: Dict[str, any] = {}  # session_id -> httpx.AsyncClient

class StartSessionRequest(BaseModel):
    registration_number: str
    password: str


def _rewrite_html(html: str, proxy_base: str) -> str:
    """
    Rewrite all VTOP absolute paths in HTML/JS/CSS to go through our proxy.
    Handles href, src, action, url(), location.href, fetch(), etc.
    """
    import re

    # Strip headers that block iframe embedding
    # (already stripped at response level, but also injected as meta just in case)

    # 1. Inject <base> tag so relative URLs route through proxy automatically
    base_tag = f'<base href="{proxy_base}">'
    if '<head>' in html:
        html = html.replace('<head>', f'<head>{base_tag}', 1)
    elif '<HEAD>' in html:
        html = html.replace('<HEAD>', f'<HEAD>{base_tag}', 1)
    else:
        html = base_tag + html

    # 2. Rewrite all quoted absolute /vtop/ references
    # Covers: href="/vtop/...", src="/vtop/...", action="/vtop/..."
    html = re.sub(
        r'(href|src|action)=(["\'])/vtop/',
        lambda m: f'{m.group(1)}={m.group(2)}{proxy_base}',
        html,
    )

    # 3. Rewrite full VTOP base URL references
    # Covers: href="https://vtop.vitap.ac.in/vtop/..."
    html = html.replace(f'"{VTOP_BASE}/vtop/', f'"{proxy_base}')
    html = html.replace(f"'{VTOP_BASE}/vtop/", f"'{proxy_base}")

    # 4. Rewrite JavaScript string literals and fetch/XHR calls
    # Covers: '/vtop/...', "/vtop/...", url: '/vtop/...'
    html = re.sub(
        r"(['\"])/vtop/",
        lambda m: f"{m.group(1)}{proxy_base}",
        html,
    )

    # 5. Rewrite JavaScript location assignments
    # Covers: window.location = "/vtop/...", location.href = "/vtop/..."
    html = re.sub(
        r'(location(?:\.href)?\s*=\s*["\'])/vtop/',
        lambda m: f'{m.group(1)}{proxy_base}',
        html,
    )

    # 6. Rewrite CSS url() calls that reference /vtop/ paths
    html = re.sub(
        r'url\(["\']?/vtop/',
        lambda m: f'url({proxy_base}',
        html,
    )

    return html


@router.post("/start_session")
async def start_proxy_session(request: StartSessionRequest):
    """
    Logs into VTOP with student credentials and returns a session ID.
    The Flutter WebView loads /vtop_proxy/session/{id}/content to get the live dashboard.
    """
    try:
        vtop = VtopClient(
            registration_number=request.registration_number,
            password=request.password,
        )
        await vtop.login()
        session_id = str(uuid.uuid4())
        # Store the underlying httpx client (already has session cookies)
        _active_clients[session_id] = vtop._client

        return {
            "session_id": session_id,
            "portal_path": f"/vtop_proxy/session/{session_id}/content",
        }
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create VTOP session: {e}",
        )


@router.api_route(
    "/session/{session_id}/{path:path}",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
)
async def proxy_vtop(session_id: str, path: str, request: Request):
    """
    Reverse-proxy for all VTOP requests under an authenticated session.
    Strips X-Frame-Options and CSP so VTOP renders inside an iframe/WebView.
    Rewrites all internal /vtop/ links to go back through this proxy.
    """
    http_client = _active_clients.get(session_id)
    if not http_client:
        raise HTTPException(status_code=404, detail="Session not found or expired. Please re-open Direct VTOP.")

    # Build upstream URL
    clean_path = path.lstrip("/")
    # If path already starts with 'vtop/' don't double it
    if clean_path.startswith("vtop/") or clean_path == "vtop":
        target_url = f"{VTOP_BASE}/{clean_path}"
    else:
        target_url = f"{VTOP_BASE}/vtop/{clean_path}"

    query_params = dict(request.query_params)
    method = request.method
    body = await request.body()

    # Safe forwarded headers
    skip_headers = {"host", "content-length", "connection", "transfer-encoding"}
    forward_headers = {
        k: v for k, v in request.headers.items()
        if k.lower() not in skip_headers
    }
    forward_headers["Referer"] = f"{VTOP_BASE}/vtop/content"
    forward_headers["Origin"] = VTOP_BASE

    try:
        upstream = await http_client.request(
            method=method,
            url=target_url,
            params=query_params if query_params else None,
            content=body if body else None,
            headers=forward_headers,
            timeout=30.0,
            follow_redirects=False,   # handle redirects ourselves so we can rewrite them
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"VTOP proxy upstream error: {e}")

    # Handle redirects — rewrite Location to go through our proxy
    if upstream.status_code in (301, 302, 303, 307, 308):
        location = upstream.headers.get("location", "")
        # If VTOP redirects to its own pages, route through proxy
        if location.startswith("/vtop/"):
            proxied_location = f"/vtop_proxy/session/{session_id}/{location.lstrip('/')}"
        elif location.startswith(VTOP_BASE + "/vtop/"):
            proxied_location = f"/vtop_proxy/session/{session_id}/" + location[len(VTOP_BASE) + 1:].lstrip("/")
        else:
            proxied_location = location
        return RedirectResponse(url=proxied_location, status_code=upstream.status_code)

    content_type = upstream.headers.get("content-type", "")

    # Strip headers that block embedding + compression that we can't pass through as-is
    blocked = {
        "x-frame-options",
        "content-security-policy",
        "content-encoding",  # we return decoded body
        "content-length",    # recalculated
        "server",
        "transfer-encoding",
        "connection",
    }
    resp_headers = {
        k: v for k, v in upstream.headers.items()
        if k.lower() not in blocked
    }

    proxy_base = f"/vtop_proxy/session/{session_id}/"

    # HTML: full rewrite
    if "text/html" in content_type:
        html = upstream.text
        html = _rewrite_html(html, proxy_base)
        return Response(
            content=html.encode("utf-8"),
            status_code=upstream.status_code,
            media_type="text/html; charset=utf-8",
            headers=resp_headers,
        )

    # JavaScript: rewrite /vtop/ string literals so XHR/fetch calls go through proxy
    if "javascript" in content_type or "application/json" in content_type:
        import re
        js = upstream.text
        # Rewrite '/vtop/...' and "/vtop/..." string literals
        js = re.sub(
            r"(['\"])/vtop/",
            lambda m: f"{m.group(1)}{proxy_base}",
            js,
        )
        js = js.replace(f'"{VTOP_BASE}/vtop/', f'"{proxy_base}')
        js = js.replace(f"'{VTOP_BASE}/vtop/", f"'{proxy_base}")
        return Response(
            content=js.encode("utf-8"),
            status_code=upstream.status_code,
            media_type=content_type,
            headers=resp_headers,
        )

    # CSS: rewrite url(/vtop/...)
    if "text/css" in content_type:
        import re
        css = upstream.text
        css = re.sub(r"url\(['\"]?/vtop/", lambda m: f"url({proxy_base}", css)
        return Response(
            content=css.encode("utf-8"),
            status_code=upstream.status_code,
            media_type=content_type,
            headers=resp_headers,
        )

    # Binary/other (images, fonts, woff, etc.) — pass raw
    return Response(
        content=upstream.content,
        status_code=upstream.status_code,
        media_type=content_type,
        headers=resp_headers,
    )
