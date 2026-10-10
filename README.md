# 📑 OMR Checker — Cloud-Powered Automated OMR Evaluation System

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.141+-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com)
[![OpenCV](https://img.shields.io/badge/OpenCV-Computer%20Vision-5C3EE8?logo=opencv&logoColor=white)](https://opencv.org)
[![SQLite](https://img.shields.io/badge/SQLite-Local%20Storage-003B57?logo=sqlite&logoColor=white)](https://sqlite.org)
[![Render](https://img.shields.io/badge/Render-Cloud%20Hosted-46E3B7?logo=render&logoColor=black)](https://render.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

An end-to-end, production-ready Optical Mark Recognition (OMR) evaluation application designed for educators and academic institutions. The system features a responsive **Flutter mobile app** paired with a high-performance **FastAPI + OpenCV computer vision backend** hosted live on the cloud, enabling instant, automated sheet scanning, answer key matching, and grading without local servers, USB cables, or specialized scanning hardware.

---

## 🌟 Key Features

- **📱 Complete Mobile Workflow**:
  - Create and manage exams with custom question limits (up to 30 objective questions for OMR-001).
  - Manage multiple exams locally with persistent offline storage.
  - Safe, transactional cascade deletion of exams, answer keys, and student evaluations.

- **🔑 Flexible Answer Key Creation**:
  - **Manual Input**: Interactive option selection (`A`, `B`, `C`, `D`, or `Blank`).
  - **Scan Solution Sheet**: Scan a pre-filled master sheet with the camera/gallery; OpenCV auto-detects and saves the answer key.
  - **Free-Mark Rule**: Mark any question as `Blank` in the answer key to grant full marks automatically to all candidates regardless of their response.

- **👁️ Computer Vision Sheet Processing (OpenCV)**:
  - **Corner Marker Detection**: Automatically identifies the 4 black registration fiducials.
  - **Perspective Correction (Homography / Warp)**: Rectifies tilted, rotated, or angled camera photos into a standardized $1370 \times 2048$ coordinate system.
  - **Bubble Darkness & Fill Ratio Measurement**: Dual-metric thresholding for reliable bubble classification (`marked`, `blank`, or `ambiguous`).

- **📊 Comprehensive Student Evaluation**:
  - Roll number entry & single-tap scan pipeline.
  - Instant scoring with 8 key metrics: Roll number, Total questions, Answered count, Correct, Wrong, Blank, Final score, and Percentage.
  - Question-by-question breakdown showing candidate's response vs. correct answer.
  - Offline-first SQLite persistence for all student evaluations.

- **☁️ Cloud Architecture (Zero Laptop / Zero Cable)**:
  - Deployed on **Render** cloud platform with 24/7 HTTPS accessibility.
  - Evaluates sheets purely over mobile data or Wi-Fi.

---

## 🏛️ System Architecture

```
[ Teacher's Smartphone ]
  │
  ├── 📱 Flutter Mobile Client (Dart)
  │     ├── Exam Management UI
  │     ├── Camera / Gallery Sheet Scanner (ImagePicker)
  │     └── Automatic Grading Engine & Breakdown
  │
  └── 🗄️ SQLite Database (sqflite)
        ├── exams Table
        ├── answer_keys Table
        └── student_evaluations Table
  │
  │  HTTPS Multipart Upload (image/jpeg)
  ▼
[ Render Cloud Platform ]
  │
  ├── ⚡ Uvicorn ASGI Server
  │
  └── 🚀 FastAPI Microservice (Python)
        │
        └── 👁️ OMR Detector (OpenCV & NumPy)
              ├── 1. Image Decode
              ├── 2. Corner Marker Detection
              ├── 3. Perspective Warp Transformation (OMR-001)
              ├── 4. Bubble Darkness & Density Extraction
              └── 5. Classification (ক, খ, গ, ঘ)
  │
  │  JSON Response (Detected Answers & Confidence)
  ▼
[ Evaluation & Instant Score Generation on Device ]
```

---

## 🛠️ Technology Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Frontend UI** | [Flutter](https://flutter.dev) (Dart) | Cross-platform native mobile app (Material 3 design) |
| **Local Storage** | [SQLite](https://sqlite.org) (`sqflite`) | Persistent offline storage for exams, keys, and results |
| **Backend API** | [FastAPI](https://fastapi.tiangolo.com) (Python 3.13) | Asynchronous, high-throughput REST API service |
| **Web Server** | [Uvicorn](https://www.uvicorn.org) | Lightning-fast ASGI web server |
| **Computer Vision** | [OpenCV](https://opencv.org) & [NumPy](https://numpy.org) | Image warping, contour detection, and bubble analysis |
| **Cloud Hosting** | [Render](https://render.com) | Free cloud container deployment with continuous Git delivery |

---

## 📂 Repository Structure

```
omr-application/
├── backend/                        # FastAPI + OpenCV computer vision service
│   ├── app/
│   │   ├── core/
│   │   │   └── template_omr001.py  # Geometric coordinates of OMR-001 sheet
│   │   ├── services/
│   │   │   └── omr_detector.py     # Image processing & bubble detection logic
│   │   └── main.py                 # FastAPI application routes (/health, /api/v1/omr/process)
│   ├── tests/
│   │   └── test_detector.py        # Pytest test suite with reference sheet verification
│   ├── requirements.txt            # Python dependencies
│   └── pytest.ini                  # Pytest configuration
│
├── mobile/                         # Flutter Android/iOS application
│   ├── lib/
│   │   ├── core/                   # App theme, styles, strings
│   │   ├── features/
│   │   │   ├── exam/               # Create exam, details, manual answer key screens
│   │   │   ├── home/               # Home screen with exam cards & delete actions
│   │   │   ├── processing/         # OMR processing & alignment visualization
│   │   │   ├── result/             # Result screen with scoring & question breakdown
│   │   │   └── scanner/            # Camera/gallery capture with student roll input
│   │   ├── models/                 # Data models (Exam, StudentEvaluation, OmrResult)
│   │   ├── services/
│   │   │   ├── database/           # SQLite service with schema v3 migrations
│   │   │   ├── image_picker_service.dart
│   │   │   └── omr_api_service.dart# HTTP client communicating with backend
│   │   └── main.dart               # Flutter application entry point
│   ├── test/                       # Flutter widget & unit test suite
│   └── pubspec.yaml                # Flutter dependencies & metadata
│
└── README.md                       # Comprehensive project documentation
```

---

## 🚀 Getting Started

### Prerequisites

- **Python 3.11+** (Python 3.13 tested)
- **Flutter SDK 3.x**
- **Android Studio / VS Code** with Android SDK installed

---

### Option 1: Running with Cloud Backend (Recommended)

The backend is deployed live on Render at:
```
https://omr-application.onrender.com
```

Build and install the release APK directly:
```bash
cd mobile
flutter build apk --release --dart-define=OMR_API_URL=https://omr-application.onrender.com
```
Install the generated APK (`mobile/build/app/outputs/flutter-apk/app-release.apk`) on any Android phone. **No laptop or local server is needed!**

---

### Option 2: Running Locally

#### 1. Start the Backend Service

```bash
cd backend

# Create virtual environment
python -m venv .venv
source .venv/bin/activate    # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Start FastAPI server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

- Health Check: `http://127.0.0.1:8000/health`
- Interactive Swagger Docs: `http://127.0.0.1:8000/docs`

#### 2. Connect Mobile Client (Over USB or LAN)

**Via USB Reverse Port Forwarding:**
```bash
adb reverse tcp:8000 tcp:8000
cd mobile
flutter run
```

**Via Local Wi-Fi / Hotspot:**
Find your PC's IP (e.g. `192.168.1.100`), ensure port 8000 is open in firewall, then run:
```bash
cd mobile
flutter run --dart-define=OMR_API_URL=http://192.168.1.100:8000
```

---

## 📡 API Reference

### Health Check
```http
GET /health
```
**Response:**
```json
{
  "status": "ok",
  "service": "omr-checker-api"
}
```

### Process OMR Sheet
```http
POST /api/v1/omr/process
Content-Type: multipart/form-data
```
| Parameter | Type | Description |
|---|---|---|
| `file` | File (`image/*`) | The photographed or scanned OMR sheet |

**Sample Response:**
```json
{
  "template_id": "OMR-001",
  "answers": [
    {
      "question": 1,
      "answer": "ক",
      "status": "marked",
      "confidence_gap": 78.4,
      "scores": { "ক": 182.5, "খ": 22.1, "গ": 18.0, "ঘ": 24.3 }
    },
    {
      "question": 2,
      "answer": null,
      "status": "blank",
      "confidence_gap": 4.1,
      "scores": { "ক": 19.0, "খ": 23.1, "গ": 21.0, "ঘ": 20.4 }
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

## 🧪 Testing & Verification

### Flutter Tests & Analysis
```bash
cd mobile
flutter analyze
flutter test
```
- Includes tests for Home screen workflow, exam creation, result calculations with free-mark rule, delete confirmation dialogs, and API client error handling.

### Backend Tests
```bash
cd backend
pytest -v
```
- Verifies image decoding, four-corner registration, perspective transformation, and 30-question grid detection on reference sheets.

---

## 📝 Evaluation Logic & Rules

| Answer Key | Candidate Bubble | Evaluated Status | Points Awarded |
|---|---|---|---|
| Option (e.g. `A`) | Matches Key (`A`) | ✅ Correct | `+1` |
| Option (e.g. `A`) | Different Option (`B`) | ❌ Wrong | `0` |
| Option (e.g. `A`) | No Bubble (`Blank`) | ⬜ Unattempted | `0` |
| **Blank / Null** | **Any or None** | ✅ **Free Mark** | `+1` |

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
