# OMR Checker Mobile

Flutter mobile client for the OMR Checker app.

## Run With Backend

1. Start the backend from `C:\Users\ANUP\omr-application\backend`:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

2. For a USB-connected Android phone, forward the backend port:

```powershell
adb reverse tcp:8000 tcp:8000
```

3. Start the app from `C:\Users\ANUP\omr-application\mobile`:

```powershell
flutter run
```

For an Android emulator, the app automatically tries `http://10.0.2.2:8000` after the USB reverse URL. For a physical phone on Wi-Fi without USB reverse, run Flutter with:

```powershell
flutter run --dart-define=OMR_API_URL=http://YOUR_PC_IP:8000
```
