from fastapi import FastAPI
from fastapi.security import APIKeyHeader
from starlette.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()

from .routers import student_data
from .routers import auth
from .routers import vtop_proxy

# This single line is all FastAPI needs to show the Authorize button in Swagger
api_key_scheme = APIKeyHeader(name="X-API-Key", auto_error=False)

app = FastAPI(
    title="VIT-AP VTOP API",
    description="A FastAPI wrapper for the vitap-vtop-client library, designed to help students access their academic information programmatically",
    version="0.1.0",
    contact={
        "name": "Know more about VITAP Student Project",
        "url": "https://vitap.udhay-adithya.me",
    },
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(student_data.router)
app.include_router(vtop_proxy.router)

@app.get("/")
async def read_root():
    return {
        "message": f"Welcome to VITAP VTOP API. Check out {app.docs_url} to get started."
    }
