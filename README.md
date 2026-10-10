# OMR Checker

An automated Optical Mark Recognition (OMR) evaluation system consisting of a Flutter mobile application and a cloud-hosted FastAPI backend powered by OpenCV.

The application allows teachers to create exams, define or scan answer keys, scan student OMR sheets using their smartphone camera, and automatically grade submissions with local SQLite persistence.

---

## Overview

Traditional OMR evaluation requires dedicated hardware scanners or manual paper-checking. This project provides an accessible, mobile-first alternative:

1. **Mobile Frontend (Flutter)**: Handles teacher interaction, exam creation, answer key configuration, camera image capture, grading display, and offline SQLite storage.
2. **Vision Backend (FastAPI + OpenCV)**: Receives uploaded sheet images, detects four corner registration markers, corrects perspective distortion via homography, measures bubble darkness across an aligned grid, and returns classified answers in JSON format.
3. **Cloud Deployment (Render)**: The backend is hosted as a cloud service, removing the need for a local development machine, USB cables, or local port forwarding during usage.

---

## Features

- **Exam Management**: Create exams, assign custom question limits (up to 30 for the OMR-001 template), and manage exam records.
- **Cascading Exam Deletion**: Deleting an exam safely clears associated student evaluations, stored answer keys, and the exam record in a single database transaction.
- **Dual Answer Key Modes**:
  - **Manual Entry**: Set correct choices (`A`, `B`, `C`, `D`, or `Blank`) per question.
  - **Scan Solution Sheet**: Upload or capture a pre-filled master sheet to automatically extract and populate the answer key via the vision backend.
- **Free-Mark Rule Support**: If a question in the answer key is left `Blank` (or unassigned), all students automatically receive full marks for that question, regardless of whether they marked an option or left it blank.
- **Computer Vision Pipeline**:
  - Four-corner fiducial marker identification via contour geometry and aspect ratio filtering.
  - Perspective transformation (`cv2.warpPerspective`) normalizing images to a standardized $1370 \times 2048$ pixel space.
  - Dual-metric bubble classification using mean inner darkness and dark pixel area ratios.
- **Student Grading & Evaluation**:
  - Manual roll number input per candidate.
  - Immediate score calculation showing total questions, answered count, correct, wrong, blank, total score, and percentage.
  - Per-question breakdown comparing student choices with the answer key.
  - Automatic persistence to local SQLite database with duplicate-save prevention guards.

---

## Architecture

```
[ Mobile Device (Teacher) ]
        │
        ├── Flutter UI (Dart)
        ├── Camera / Gallery Image Picker
        ├── Offline Evaluation Engine & Scoring
        └── SQLite Database (sqflite)
                ├── exams
                ├── answer_keys
                └── student_evaluations
        │
        │ HTTPS (POST /api/v1/omr/process)
        ▼
[ Cloud Backend (Render) ]
        │
        ├── Uvicorn ASGI Server
        └── FastAPI Application (Python)
                │
                └── OpenCV Detector
                        ├── Marker detection & validation
                        ├── Perspective correction (Homography)
                        ├── Grid patch extraction
                        └── Bubble score classification
```

---

## Technology Stack

- **Mobile Client**: Flutter 3.x, Dart, Material 3, sqflite, path, http, image_picker
- **Backend Service**: Python 3.13, FastAPI, Uvicorn, OpenCV (`opencv-python-headless`), NumPy
- **Cloud Infrastructure**: Render (Web Service container environment)
- **Database**: Local SQLite (schema version 3)

---

## Project Structure

```
omr-application/
├── backend/
│   ├── app/
│   │   ├── core/
│   │   │   └── template_omr001.py   # Coordinate grid for the OMR-001 sheet
│   │   ├── services/
│   │   │   └── omr_detector.py      # Core image rectification and bubble detection
│   │   └── main.py                  # FastAPI route declarations & CORS configuration
│   ├── tests/
│   │   └── test_detector.py         # Pytest suite validating reference sheet detection
│   ├── requirements.txt             # Python dependencies
│   └── pytest.ini                   # Pytest configuration
│
├── mobile/
│   ├── lib/
│   │   ├── core/                    # Theme, styling, and application constants
│   │   ├── features/
│   │   │   ├── exam/                # Exam creation, detail, and manual answer key screens
│   │   │   ├── home/                # Home screen with exam listing and deletion flow
│   │   │   ├── processing/          # Detection pipeline loading and status screen
│   │   │   ├── result/              # Evaluation display, grading calculations, breakdown
│   │   │   └── scanner/             # Student sheet capture and roll number entry
│   │   ├── models/                  # Exam, StudentEvaluation, and OmrResult models
│   │   ├── services/
│   │   │   ├── database/            # SQLite DatabaseService (schema migrations & queries)
│   │   │   ├── image_picker_service.dart
│   │   │   └── omr_api_service.dart # HTTP client handling multipart backend uploads
│   │   └── main.dart                # Application entrypoint
│   ├── test/
│   │   ├── omr_api_service_test.dart# API client unit tests
│   │   └── widget_test.dart         # Flutter widget test suite
│   └── pubspec.yaml                 # Mobile dependencies and project metadata
│
└── README.md
```

---

## Getting Started

### Using the Pre-built Release APK (Cloud Backend)

The backend is deployed and running on Render:
```
https://omr-application.onrender.com
```

To build and run the release APK against this cloud endpoint:

```bash
cd mobile
flutter build apk --release --dart-define=OMR_API_URL=https://omr-application.onrender.com
```

The compiled APK will be generated at:
```
mobile/build/app/outputs/flutter-apk/app-release.apk
```

Install this APK on an Android device. The app requires an active internet connection to communicate with the cloud vision backend during sheet scans.

---

### Running the Backend Locally

If you prefer running the Python vision engine on your local machine:

1. Navigate to the backend directory and set up a virtual environment:

   ```bash
   cd backend
   python -m venv .venv
   ```

   Activate the virtual environment:
   - **Windows**: `.venv\Scripts\activate`
   - **Linux / macOS**: `source .venv/bin/activate`

2. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```

3. Start the Uvicorn server:

   ```bash
   uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

   - Health Check: `GET http://127.0.0.1:8000/health`
   - Swagger Documentation: `http://127.0.0.1:8000/docs`

---

### Running the Mobile App Locally

1. Ensure an Android device or emulator is connected.
2. If testing against a local backend running on your PC, forward the port via ADB:

   ```bash
   adb reverse tcp:8000 tcp:8000
   ```

3. Launch the application:

   ```bash
   cd mobile
   flutter run
   ```

---

## API Reference

### Health Check

Verifies backend service availability.

- **URL**: `/health`
- **Method**: `GET`
- **Response**:
  ```json
  {
    "status": "ok",
    "service": "omr-checker-api"
  }
  ```

---

### Process OMR Sheet

Uploads an image for corner detection, perspective correction, and bubble reading.

- **URL**: `/api/v1/omr/process`
- **Method**: `POST`
- **Content-Type**: `multipart/form-data`
- **Form Fields**:
  - `file`: Image file (`.jpg`, `.png`)

**Success Response (200 OK)**:
```json
{
  "template_id": "OMR-001",
  "answers": [
    {
      "question": 1,
      "answer": "ক",
      "status": "marked",
      "confidence_gap": 78.4,
      "scores": {
        "ক": 182.5,
        "খ": 22.1,
        "গ": 18.0,
        "ঘ": 24.3
      }
    },
    {
      "question": 2,
      "answer": null,
      "status": "blank",
      "confidence_gap": 4.1,
      "scores": {
        "ক": 19.0,
        "খ": 23.1,
        "গ": 21.0,
        "ঘ": 20.4
      }
    }
  ],
  "summary": {
    "total_questions": 30,
    "marked": 24,
    "blank": 6,
    "ambiguous": 0
  }
}
```

---

## Evaluation & Scoring Rules

| Answer Key Condition | Student Detected Answer | Evaluation Result | Marks |
|---|---|---|---|
| Option selected (`A`, `B`, `C`, `D`) | Matches Answer Key | Correct | +1 |
| Option selected (`A`, `B`, `C`, `D`) | Differs from Answer Key | Wrong | 0 |
| Option selected (`A`, `B`, `C`, `D`) | Blank / Unanswered | Blank | 0 |
| **Blank / Not Specified** | **Any option or Blank** | **Free Mark** | **+1** |

---

## Testing

### Mobile Tests

Run static analysis and the Flutter test suite:

```bash
cd mobile
flutter analyze
flutter test
```

Test coverage includes:
- Home workflow and exam creation
- Delete confirmation and cascading SQLite purge
- Scoring calculations with the free-mark rule
- Roll number entry validation
- API service upload and error response parsing

### Backend Tests

Execute the Python test suite:

```bash
cd backend
pytest -v
```

Validates marker localization, perspective homography, and answer classification against clean template reference sheets.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
