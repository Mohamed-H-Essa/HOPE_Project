# HOPE — Build Guide

Step-by-step from empty folders to a running demo.

---

## Prerequisites

- Flutter SDK installed and `flutter doctor` happy
- AWS CLI configured (`aws configure`)
- Python 3.12 available locally for testing
- An AWS account with permissions to create Lambda, API Gateway, DynamoDB, S3, IAM roles

---

## Phase 1: AWS Infrastructure (do this first)

### 1.1 — Create DynamoDB Table

```bash
aws dynamodb create-table \
  --table-name hope-sessions \
  --attribute-definitions AttributeName=session_id,AttributeType=S \
  --key-schema AttributeName=session_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-3
```

### 1.2 — Create S3 Bucket

```bash
aws s3 mb s3://hope-data-$(aws sts get-caller-identity --query Account --output text) --region eu-west-3
```

Block all public access — access will only be via presigned URLs.

### 1.3 — Create IAM Role for Lambda

Create a role named `hope-lambda-role` with a trust policy for `lambda.amazonaws.com` and attach the permissions from `docs/backend.md` (DynamoDB + S3 + CloudWatch Logs).

### 1.4 — Create the Assessment Lambda (`hope-assess`)

```bash
cd backend/lambdas/hope_assess

# Create deployment package
cp ../../storm/storm/assesment_hope.py assess_logic.py
# Edit assess_logic.py: remove Flask/threading, change assess_session() to return dict
zip deployment.zip handler.py assess_logic.py

aws lambda create-function \
  --function-name hope-assess \
  --runtime python3.12 \
  --role arn:aws:iam::<account>:role/hope-lambda-role \
  --handler handler.handler \
  --zip-file fileb://deployment.zip \
  --timeout 30 \
  --memory-size 256 \
  --region eu-west-3
```

**Test it locally first:**
```bash
python3 -c "
from assess_logic import assess_session
import json

# Use sample data (copy a few rows from ESP32 serial output)
sample = [
  {'time': 1000, 'flex1': 45, 'flex2': 38, 'fsr1': 62, 'fsr2': 55, 'emg': 340,
   'ax': 1024, 'ay': -512, 'az': 16384, 'gx': 100, 'gy': -50, 'gz': 30},
  # ... add more samples
]
print(json.dumps(assess_session(sample), indent=2))
"
```

### 1.5 — Create the Exercise Lambda (`hope-exercise`)

```bash
cd backend/lambdas/hope_exercise

cp ../../storm/storm/exersisehope.py exercise_logic.py
# Edit exercise_logic.py: remove Flask/threading (run_exercise is already fine)
zip deployment.zip handler.py exercise_logic.py

aws lambda create-function \
  --function-name hope-exercise \
  --runtime python3.12 \
  --role arn:aws:iam::<account>:role/hope-lambda-role \
  --handler handler.handler \
  --zip-file fileb://deployment.zip \
  --timeout 30 \
  --memory-size 256 \
  --region eu-west-3
```

### 1.6 — Create the Session API Lambda (`hope-session-api`)

```bash
cd backend/lambdas/hope_session_api
zip deployment.zip handler.py

aws lambda create-function \
  --function-name hope-session-api \
  --runtime python3.12 \
  --role arn:aws:iam::<account>:role/hope-lambda-role \
  --handler handler.handler \
  --zip-file fileb://deployment.zip \
  --timeout 10 \
  --memory-size 128 \
  --region eu-west-3
```

**Update the bucket name** in all three handlers — replace `hope-data-{account-id}` with your actual bucket name.

### 1.7 — Create API Gateway

Create a REST API via AWS Console (or CLI):

1. New REST API named `hope-api`
2. Create resource `/sessions` with `POST` and `GET` methods
3. Create resource `/sessions/{session_id}` with sub-resources:
   - `/sessions/{session_id}/questionnaire` — `PUT`
   - `/sessions/{session_id}/assess` — `POST`
   - `/sessions/{session_id}/exercise` — `POST`
   - `/sessions/{session_id}/video-upload-url` — `POST`
   - `/sessions/{session_id}` — `GET`
4. Wire each method to the appropriate Lambda:
   - `hope-session-api`: handles `POST /sessions`, `GET /sessions`, `GET /sessions/{session_id}`, `PUT /sessions/{session_id}/questionnaire`, `POST /sessions/{session_id}/video-upload-url`
   - `hope-assess`: handles `POST /sessions/{session_id}/assess`
   - `hope-exercise`: handles `POST /sessions/{session_id}/exercise`
5. Enable CORS on all resources (Actions → Enable CORS)
6. Deploy to a stage named `prod`
7. Note the base URL: `https://<id>.execute-api.eu-west-3.amazonaws.com/prod`

### 1.8 — Test Backend with curl

```bash
BASE="https://<id>.execute-api.eu-west-3.amazonaws.com/prod"

# Create a session
SESSION=$(curl -s -X POST "$BASE/sessions" | python3 -c "import sys,json; print(json.load(sys.stdin)['session_id'])")
echo "Session ID: $SESSION"

# Save questionnaire
curl -s -X PUT "$BASE/sessions/$SESSION/questionnaire" \
  -H "Content-Type: application/json" \
  -d '{"answers": {"pain_level": 5, "stiffness": false, "comments": "test"}}'

# Simulate ESP32 assessment POST (small sample)
curl -s -X POST "$BASE/sessions/$SESSION/assess" \
  -H "Content-Type: application/json" \
  -d '[{"time":1000,"flex1":45,"flex2":38,"fsr1":62,"fsr2":55,"emg":340,"ax":1024,"ay":-512,"az":16384,"gx":100,"gy":-50,"gz":30},{"time":1050,"flex1":46,"flex2":39,"fsr1":63,"fsr2":56,"emg":350,"ax":1030,"ay":-510,"az":16390,"gx":105,"gy":-48,"gz":32}]'

# Check session (should have assessment_results now)
curl -s "$BASE/sessions/$SESSION" | python3 -m json.tool

# Simulate exercise
curl -s -X POST "$BASE/sessions/$SESSION/exercise" \
  -H "Content-Type: application/json" \
  -d '{"data": [{"time":1000,"flex1":45,"flex2":38,"fsr1":62,"fsr2":55,"emg":340,"ax":1024,"ay":-512,"az":16384,"gx":100,"gy":-50,"gz":30}], "exercise": "Grasp"}'

# List sessions
curl -s "$BASE/sessions" | python3 -m json.tool
```

Backend is ready when all 5 curl calls return expected JSON.

---

## Phase 2: Flutter App Shell

### 2.1 — Install Dependencies

```bash
cd flutter_app
# Edit pubspec.yaml: add provider, http, camera, video_player, uuid
flutter pub get
```

### 2.2 — Set API Base URL

Edit `flutter_app/lib/config.dart`:
```dart
class AppConfig {
  static const String apiBaseUrl =
      'https://<your-id>.execute-api.eu-west-3.amazonaws.com/prod';
}
```

### 2.3 — Create Folder Structure

```bash
mkdir -p lib/models lib/services lib/state lib/screens/patient lib/screens/practitioner lib/widgets
```

### 2.4 — Build in This Order

1. `lib/models/` — data classes (no dependencies)
2. `lib/services/api_service.dart` — test each method against live API
3. `lib/services/video_service.dart`
4. `lib/state/session_provider.dart`
5. `lib/main.dart` — MaterialApp + ChangeNotifierProvider + theme

---

## Phase 3: Patient Screens

Build screens in flow order — each one is simple once the provider is ready:

1. `home_screen.dart` — two buttons, no logic
2. `session_start_screen.dart` — one button, calls `provider.startSession()`
3. `questionnaire_screen.dart` — form + skip/submit
4. `assess_waiting_screen.dart` — starts polling on init, auto-navigates when done
5. `assessment_results_screen.dart` — display only (ResultCard widgets)
6. `exercise_screen.dart` — camera optional, polling when "Done" tapped
7. `exercise_results_screen.dart` — display only (ScoreBar widgets)

**Smoke test patient flow:**
1. Run app on device/emulator
2. Tap "Patient" → "Start Session"
3. Fill in questionnaire, tap Submit
4. App shows assessment waiting screen
5. Run the curl assess command above with `SESSION=<id from app>`
6. App should auto-navigate to assessment results within ~3 seconds
7. Tap "Continue to Exercises" → exercise screen
8. Tap "Done" (no video for now)
9. Run the curl exercise command above
10. App should auto-navigate to exercise results

---

## Phase 4: Practitioner Screens

1. `session_list_screen.dart` — calls `provider.loadSessionHistory()` on init
2. `session_detail_screen.dart` — displays all fields, video if present

**Smoke test:**
1. Tap "Practitioner" from home
2. Session list should show the session created in Phase 3
3. Tap into it — all data should be visible

---

## Phase 5: Video Feature

### 5.1 — iOS/Android Camera Permissions

**iOS** — add to `flutter_app/ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>HOPE needs camera access to record your exercise session</string>
<key>NSMicrophoneUsageDescription</key>
<string>HOPE needs microphone access when recording video</string>
```

**Android** — add to `flutter_app/android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

### 5.2 — Implement and Test

1. Implement `VideoService.initCamera()`, `startRecording()`, `stopRecording()`
2. Wire into `exercise_screen.dart`
3. Implement `VideoService.uploadToS3()` — HTTP PUT with raw bytes to presigned URL
4. Test: record a 5-second clip, upload, verify file appears in S3 console
5. Test video playback: open practitioner detail screen, tap the session with video

---

## Phase 6: Final Integration + Polish

1. Test full flow end-to-end with the actual ESP32 (update sketch URL to API Gateway)
2. Handle network errors gracefully (show SnackBar, allow retry)
3. Handle loading states on all screens (no blank screen while waiting)
4. Test on both iOS and Android
5. Run `flutter analyze` — fix any warnings

---

## Updating a Lambda

After editing handler code:

```bash
cd backend/lambdas/hope_assess
zip deployment.zip handler.py assess_logic.py
aws lambda update-function-code \
  --function-name hope-assess \
  --zip-file fileb://deployment.zip \
  --region eu-west-3
```

---

## Common Issues

| Problem | Fix |
|---------|-----|
| ESP32 SSL error | Use `WiFiClientSecure` or `client.setInsecure()` for demo |
| App polling times out | Check if ESP32 session_id matches what the app created |
| DynamoDB decimal error | Numbers from Python must be stored as strings or use `Decimal` type |
| S3 CORS error on video upload | Add CORS policy to S3 bucket allowing PUT from `*` |
| Camera not working on iOS simulator | Must test on physical device |
