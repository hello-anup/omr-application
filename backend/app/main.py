import logging

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from app.services.omr_detector import process_omr_image

logger = logging.getLogger(__name__)

APP_NAME = "OMR Checker API"
APP_VERSION = "0.1.0"
MAX_UPLOAD_BYTES = 10 * 1024 * 1024
ALLOWED_TYPES = {
    "image/jpeg",
    "image/png",
    "image/jpg",
    "image/pjpeg",
    "application/octet-stream",
}
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}

app = FastAPI(
    title=APP_NAME,
    description="Checks OMR answer sheets from an uploaded image",
    version=APP_VERSION,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {
        "title": APP_NAME,
        "version": APP_VERSION,
        "docs_url": "/docs",
        "health_url": "/health",
    }


@app.api_route("/health", methods=["GET", "HEAD"])
def health_check():
    return {"status": "ok", "version": APP_VERSION}


@app.post("/api/v1/omr/process")
async def process_omr(file: UploadFile = File(...)):
    content_type = (file.content_type or "").split(";")[0].strip().lower()
    filename = (file.filename or "").lower()
    has_valid_ext = any(filename.endswith(ext) for ext in ALLOWED_EXTENSIONS)

    if content_type and content_type not in ALLOWED_TYPES and not has_valid_ext:
        raise HTTPException(status_code=415, detail="Please upload a JPEG or PNG image.")

    data = await file.read()

    if not data:
        raise HTTPException(status_code=400, detail="Uploaded image is empty.")
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Image is too large (max 10 MB).")

    try:
        result = process_omr_image(data)
    except ValueError as exc:
        logger.warning("Could not process %s: %s", file.filename, exc)
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    logger.info("Processed %s", file.filename)
    return result
