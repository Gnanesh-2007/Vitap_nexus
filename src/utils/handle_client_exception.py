from fastapi import HTTPException
from vitap_vtop_client.exceptions import VitapVtopClientError

def handle_client_exception(e: VitapVtopClientError):
    raise HTTPException(status_code=400, detail=str(e))
