# HOPE — Build Guide

Step-by-step from empty folders to a running demo.

---

## Prerequisites

- Flutter SDK installed and `flutter doctor` happy
- AWS CLI configured (`aws configure`)
- Python 3.12 available locally for testing
- An AWS account with permissions to create Lambda, API Gateway, DynamoDB, S3, IAM roles
- Arduino IDE with ESP32 Arduino core 2.x and MPU6050 library by Electronic Cats

---

## Phase 1: AWS Infrastructure (do this first)

### 1.1 — Deploy Everything

The `deploy.sh` script handles all AWS resource creation:

```bash
REGION=us-east-1 ./backend/infra/deploy.sh
```

This creates:
- IAM role (`hope-lambda-role`)
- DynamoDB table (`hope-sessions`)
- S3 bucket (`hope-data-{account-id}`)
- 2 Lambda functions (`hope_session_api`, `hope_ingest`)
- API Gateway with all routes
- Deploys to `prod` stage

The script prints the API base URL when done.

### 1.2 — Test Backend with curl

```bash
BASE="https://<id>.execute-api.us-east-1.amazonaws.com/prod"

# Create a session
SESSION=$(curl -s -X POST "$BASE/sessions" | python3 -c "import sys,json; print(json.load(sys.stdin)['session_id'])")
echo "Session ID: $SESSION"

# Save questionnaire (runs AFTER assessment in the real app flow; placed here for easy copy-paste testing)
# The app sends the raw object shape. Backend also accepts {"answers": {...}} wrapping.
curl -s -X PUT "$BASE/sessions/$SESSION/questionnaire" \
  -H "Content-Type: application/json" \
  -d '{"pain_level": 5, "stiffness": false, "comments": "test", "goal": "improve_grip"}'

# Link device
curl -s -X PUT "$BASE/sessions/$SESSION/device" \
  -H "Content-Type: application/json" \
  -d '{"device_id": "hope-glove-01"}'

# Simulate ESP32 ingest (assessment)
curl -s -X POST "$BASE/ingest" \
  -H "Content-Type: application/json" \
  -d '{"device_id": "hope-glove-01", "data": [{"time":1000,"flex1":45,"flex2":38,"fsr1":62,"fsr2":55,"emg":340,"ax":1024,"ay":-512,"az":16384,"gx":100,"gy":-50,"gz":30},{"time":1050,"flex1":46,"flex2":39,"fsr1":63,"fsr2":56,"emg":350,"ax":1030,"ay":-510,"az":16390,"gx":105,"gy":-48,"gz":32}]}'

# Check session (should have assessment_results now)
curl -s "$BASE/sessions/$SESSION" | python3 -m json.tool

# Simulate ESP32 ingest (exercise — backend auto-detects because status is now 'assessed')
curl -s -X POST "$BASE/ingest" \
  -H "Content-Type: application/json" \
  -d '{"device_id": "hope-glove-01", "data": [{"time":1000,"flex1":45,"flex2":38,"fsr1":62,"fsr2":55,"emg":340,"ax":1024,"ay":-512,"az":16384,"gx":100,"gy":-50,"gz":30}]}'

# List sessions
curl -s "$BASE/sessions" | python3 -m json.tool
```

### 1.3 — Run the Full Demo Script

```bash
python3 demo.py
```

This simulates the complete session flow end-to-end against the live backend.

---

## Phase 2: Flash ESP32 Firmware

### 2.1 — Open in Arduino IDE

Open `firmware/hope_glove/hope_glove.ino` in Arduino IDE.

### 2.2 — Configure

1. Set `WIFI_SSID` and `WIFI_PASSWORD` to the local WiFi credentials
2. Verify `INGEST_URL` matches the API base URL from deploy + `/ingest`
3. Verify `DEVICE_ID` matches what the Flutter app will use in `PUT /sessions/{id}/device`

### 2.3 — Install Libraries

Via Arduino IDE Library Manager:
- **MPU6050** by Electronic Cats (also installs I2Cdev dependency)

No other libraries needed — WiFiClientSecure and HTTPClient are bundled with ESP32 core.

### 2.4 — Flash

Board: ESP32 Dev Module. Upload. The glove will:
1. Connect to WiFi
2. Collect 100 sensor samples (5 seconds at 50ms intervals)
3. POST to `/ingest` with `device_id` and data
4. If 200: wait 5s, collect next batch
5. If 404 (no session linked): wait 3s, retry
6. Repeat forever

---

## Phase 3: Flutter App Shell

### 3.1 — Set API Base URL

Edit `flutter_app/lib/config.dart`:
```dart
class AppConfig {
  static const String apiBaseUrl =
      'https://<your-id>.execute-api.us-east-1.amazonaws.com/prod';
}
```

### 3.2 — Build in This Order

1. `lib/models/` — data classes (no dependencies)
2. `lib/services/api_service.dart` — test each method against live API
3. `lib/services/video_service.dart`
4. `lib/state/session_provider.dart`
5. `lib/main.dart` — MaterialApp + ChangeNotifierProvider + theme

---

## Phase 4: Patient Screens

Build screens in flow order:

1. `home_screen.dart` — two buttons, no logic
2. `session_start_screen.dart` — calls `provider.startSession()`
3. `questionnaire_screen.dart` — form + skip/submit
4. `device_link_screen.dart` — links device to session, then waits
5. `assess_waiting_screen.dart` — polls until assessment_results appears
6. `assessment_results_screen.dart` — PASS/FAIL display
7. `exercise_screen.dart` — camera optional, polling when "Done" tapped
8. `exercise_results_screen.dart` — scores + message

---

## Phase 5: Practitioner Screens

1. `session_list_screen.dart` — calls `provider.loadSessionHistory()` on init
2. `session_detail_screen.dart` — displays all fields, video if present

---

## Phase 6: Video Feature

See flutter.md for camera/video implementation details.

---

## Phase 7: Final Integration + Polish

1. Test full flow end-to-end with the actual ESP32
2. Handle network errors gracefully
3. Handle loading states on all screens
4. Test on both iOS and Android
5. Run `flutter analyze`

---

## Infrastructure Scripts

```bash
# Deploy (or update) backend
REGION=us-east-1 ./backend/infra/deploy.sh

# Reset data between demos (URL survives)
./backend/infra/cleanup.sh

# Full teardown (URL changes on next deploy)
./backend/infra/teardown.sh

# Run tests
cd backend && pytest tests/ -v
```

---

## Common Issues

| Problem | Fix |
|---------|-----|
| ESP32 SSL error | Firmware uses `WiFiClientSecure` + `setInsecure()` for demo |
| App polling times out | Check if device is linked to the session via `PUT /sessions/{id}/device` |
| Glove gets 404 | No active session linked — create session + link device in Flutter app first |
| DynamoDB decimal error | `hope_ingest` handler uses `Decimal` conversion and custom JSON encoder |
| S3 CORS error on video upload | `deploy.sh` sets up CORS policy on the S3 bucket |
| Camera not working on iOS simulator | Must test on physical device |
| URL changed after teardown | Update `INGEST_URL` in firmware and `apiBaseUrl` in Flutter app, then reflash ESP32 |
