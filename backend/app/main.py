from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from app.services.omr_detector import process_omr_image

app = FastAPI(
    title="OMR Checker API",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def root():
    return {
        "title": "OMR Checker API",
        "version": "0.1.0",
        "docs_url": "/docs",
        "health_url": "/health",
    }


@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "service": "omr-checker-api",
        "version": "0.1.0",
    }

@app.post("/api/v1/omr/process")
async def process_omr(file: UploadFile = File(...)):
    data = await file.read()

    if not data:
        raise HTTPException(
            status_code=400,
            detail="Uploaded image is empty.",
        )

    try:
        return process_omr_image(data)
    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        ) from exc
