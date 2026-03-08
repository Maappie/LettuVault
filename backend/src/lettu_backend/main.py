
from fastapi import FastAPI

# this is a metadata
app = FastAPI(
    title="LettuVault API",
    description="The central api gateway for the LettuVault storage system",
    version="0.1.0"
)

@app.get("/")
async def root():
    return {
        "message": "Hello LettuVault!",
        "status": "Online",
        "environment": "Development"
    }

@app.get("/health")
async def health_check():
    return {
        "status": "Healthy"
    }