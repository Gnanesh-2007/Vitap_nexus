from fastapi import HTTPException
from vitap_vtop_client.exceptions import VitapVtopClientError


def handle_client_exception(e: VitapVtopClientError):
    status_code = e.status_code if e.status_code is not None else 400
    raise HTTPException(status_code=status_code, detail=str(e))
