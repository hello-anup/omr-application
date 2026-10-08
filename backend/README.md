# OMR Checker Backend

Python 3.13 + FastAPI + OpenCV.

## Run

From `C:\Users\ANUP\omr-application\backend`:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Health:
`GET http://127.0.0.1:8000/health`

Swagger:
`http://127.0.0.1:8000/docs`

OMR processing:
`POST /api/v1/omr/process`
with multipart field `file`.

## Scope

The backend implements:
- FastAPI foundation
- image upload endpoint
- four black corner-marker detection
- perspective normalization to the OMR-001 reference geometry
- fixed-grid detection for the 30 objective answer bubbles

Roll number, registration number, subject code and set code are intentionally not returned by the current detector.
