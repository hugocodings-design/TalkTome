# Phase 1 Setup & Completion Checklist

## Backend Setup (Python/FastAPI)

### Prerequisites
- Python 3.8+ installed
- Google Cloud account with TTS API enabled
- Google Cloud service account JSON key

### Step 1: Backend Installation
```bash
cd backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Step 2: Google Cloud TTS Setup
1. Create a Google Cloud project: https://console.cloud.google.com
2. Enable Text-to-Speech API
3. Create a service account and download JSON key
4. Set environment variable:
   ```bash
   # Windows (PowerShell)
   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\your\key.json"
   
   # macOS/Linux
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/key.json"
   ```

### Step 3: Run Backend
```bash
# Navigate to backend folder
cd backend

# Start FastAPI server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

**Expected output:**
```
Uvicorn running on http://127.0.0.1:8000
```

### Step 4: Test Backend Endpoints
```bash
# Health check
curl http://localhost:8000/api/health

# Get voices
curl http://localhost:8000/api/voices

# Test TTS (requires text)
curl -X POST http://localhost:8000/api/synthesize \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello world","voice_name":"en-US-Neural2-C"}'
```

---

## Flutter Setup

### Prerequisites
- Flutter SDK (>= 3.0) installed
- Android SDK/Emulator or physical Android device
- Android Studio (recommended)

### Step 1: Check Flutter Installation
```bash
flutter --version
flutter doctor
```

### Step 2: Install Flutter Dependencies
```bash
cd flutter_app

# Get all pub dependencies
flutter pub get

# Generate Hive adapters (required for local database)
flutter pub run build_runner build
```

### Step 3: Configure Backend URL
Edit `flutter_app/lib/services/tts_service.dart`:
- Update `apiBaseUrl` to match your backend URL
- Default: `"http://localhost:8000"` (for local testing)
- For Android emulator, use `"http://10.0.2.2:8000"`

### Step 4: Run Flutter App
```bash
cd flutter_app

# List available devices
flutter devices

# Run on Android emulator
flutter run

# Or run on specific device/emulator
flutter run -d <device_id>
```

**For development (hot reload):**
```bash
flutter run
# Then press 'r' to hot reload after code changes
```

---

## Phase 1 Verification Checklist

- [ ] Backend service running on http://localhost:8000
- [ ] `/api/health` returns `{"status":"ok"}`
- [ ] `/api/voices` returns list of 8+ voices
- [ ] `/api/synthesize` accepts POST with text and voice_name
- [ ] Flutter project compiles without errors
- [ ] `flutter pub get` completes successfully
- [ ] `flutter pub run build_runner build` generates adapters
- [ ] Flutter app launches on Android emulator/device
- [ ] App can open file picker (no crash)
- [ ] Backend accessible from Flutter app

---

## Troubleshooting

### Backend Issues
**"Google Cloud TTS client not initialized"**
- Solution: Set GOOGLE_APPLICATION_CREDENTIALS environment variable
  ```bash
  # Verify it's set
  echo $env:GOOGLE_APPLICATION_CREDENTIALS  # Windows
  echo $GOOGLE_APPLICATION_CREDENTIALS      # macOS/Linux
  ```

**Port 8000 already in use**
- Solution: Use different port
  ```bash
  uvicorn main:app --port 8001
  ```
- Then update Flutter `apiBaseUrl` to `http://localhost:8001`

### Flutter Issues
**"Unable to locate Android SDK"**
- Solution: Run `flutter config --android-sdk-path /path/to/android/sdk`

**"Gradle build failed"**
- Solution: 
  ```bash
  flutter clean
  flutter pub get
  flutter run
  ```

**"Build Runner not generating files"**
- Solution:
  ```bash
  flutter pub run build_runner build --delete-conflicting-outputs
  ```

**"App crashes on startup"**
- Solution: Check logs
  ```bash
  flutter run -v  # Verbose logging
  ```

### Network Issues
**"Connection refused" when Flutter calls backend**
- For Android emulator: Use `10.0.2.2:8000` instead of `localhost:8000`
- For physical device: Use your computer's local IP (e.g., `192.168.x.x:8000`)

---

## Next Steps (Phase 2)

Once Phase 1 verification passes:
1. Implement file upload and text extraction
2. Build UI for chapter selection
3. Implement TTS text chunking logic
4. Add voice selection UI

---

## useful Commands Reference

```bash
# Backend
cd backend
python -m venv venv
pip install -r requirements.txt
uvicorn main:app --reload

# Flutter
flutter create talktome                     # Create new project
flutter pub get                             # Install dependencies
flutter pub run build_runner build          # Generate Hive adapters
flutter run                                 # Run app
flutter run -v                              # Run with verbose logging
flutter clean                               # Clean build
flutter devices                             # List connected devices
flutter pub upgrade                         # Upgrade dependencies
```

---

## API Documentation (Backend)

### GET /api/health
Returns server status.

**Response:**
```json
{"status": "ok", "service": "TalkTome API"}
```

---

### GET /api/voices
Returns list of available TTS voices.

**Response:**
```json
{
  "voices": [
    {
      "name": "en-US-Neural2-A",
      "display_name": "English (US) - Neural A (Female)",
      "language_code": "en-US"
    },
    ...
  ]
}
```

---

### POST /api/synthesize
Synthesize text to speech.

**Request:**
```json
{
  "text": "Hello, how are you?",
  "voice_name": "en-US-Neural2-C",
  "language_code": "en-US"
}
```

**Response:**
```json
{
  "audio_content": "base64-encoded-mp3-audio",
  "voice_used": "en-US-Neural2-C",
  "characters_used": 20,
  "format": "mp3"
}
```

---

## Estimated Time for Phase 1
- Backend setup: 15 minutes
- Google Cloud configuration: 30 minutes (first time)
- Flutter setup: 20 minutes
- Testing endpoints: 10 minutes

**Total: ~1.5 hours**
