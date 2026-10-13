import logging

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from app.services.omr_detector import process_omr_image

logger = logging.getLogger(__name__)

app = FastAPI(
    title="OMR Checker API",
    description="Automated OMR evaluation service for objective answer sheets",
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
    """Return service health and version metadata."""
    return {
        "status": "ok",
        "service": "omr-checker-api",
        "version": "0.1.0",
    }

@app.post("/api/v1/omr/process")
async def process_omr(file: UploadFile = File(...)):
    logger.info("Received OMR upload request: %s", file.filename)
    data = await file.read()

    if not data:
        logger.warning("Rejected upload with empty payload: %s", file.filename)
        raise HTTPException(
            status_code=400,
            detail="Uploaded image is empty.",
        )

    try:
        result = process_omr_image(data)
        logger.info("Successfully processed OMR sheet: %s", file.filename)
        return result
    except ValueError as exc:
        logger.warning("Validation error processing %s: %s", file.filename, exc)
        raise HTTPException(
            status_code=422,
            detail=str(exc),
        ) from exc
