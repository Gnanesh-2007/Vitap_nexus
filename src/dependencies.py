from fastapi import Header, HTTPException, Security
from fastapi.security import APIKeyHeader

from .config import settings

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

async def verify_api_key(api_key: str = Security(api_key_header)):
    """
    Dependency to verify the API Key provided in the X-API-Key header.
    Using Security() instead of Header() so Swagger UI shows the Authorize button.
    """
    if api_key is None:
        raise HTTPException(status_code=401, detail="API Key missing")
    if api_key != settings.API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
