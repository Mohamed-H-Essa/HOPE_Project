# HOPE — Architecture

## What It Is

HOPE is a weekend demo for a smart rehabilitation glove. A patient wears an ESP32-based glove that reads flex sensors, force-sensitive resistors (FSR), an EMG sensor, and an IMU (MPU6050). The system assesses the patient's hand function and scores their rehabilitation exercises. A Flutter app serves as the UI for both patients and practitioners.

## System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  ESP32 Glove                                                  │
│  Sensors: 2x Flex, 2x FSR, EMG, IMU (MPU6050)               │
│  Firmware: firmware/hope_glove/hope_glove.ino                │
│                                                               │
│  The glove is a dumb data pipe. It collects 100 sensor       │
│  samples, POSTs them to /ingest with its device_id, and      │
│  repeats. It has NO knowledge of sessions, modes, or          │
│  exercise names.                                              │
└────────────────────┬─────────────────────────────────────────┘
                     │ WiFi (HTTPS)
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  AWS API Gateway (REST)                                       │
│  Endpoints — see api.md for full contract                     │
└────────────────────┬─────────────────────────────────────────┘
                     │
               ┌─────┴──────┐
               ▼            ▼
        ┌───────────┐ ┌───────────┐
        │  Lambda   │ │  Lambda   │
        │  session  │ │  ingest   │
        │  _api     │ │           │
        └─────┬─────┘ └─────┬─────┘
              │             │
              └──────┬──────┘
                     ▼
   ┌───────────────────┐     ┌──────────────────┐
   │    DynamoDB       │     │       S3          │
   │  hope-sessions    │     │  Raw sensor data  │
   │  (results, meta)  │     │  Videos           │
   └───────────────────┘     └──────────────────┘
              ▲
              │ polls every 3s
┌─────────────┴────────────────────────────────────────────────┐
│  Flutter App (iOS / Android)                                  │
│                                                               │
│  Patient mode:  session flow (create, questionnaire,          │
│                 link device, wait for results)                │
│  Practitioner mode: read-only session history viewer          │
│                                                               │
│  The app NEVER sends sensor data.                             │
│  It creates sessions, links the device, submits               │
│  questionnaires, uploads video, and polls for results.        │
└──────────────────────────────────────────────────────────────┘
```

## Key Design Decision: Dumb Glove

The glove has no concept of assess vs exercise. It just collects and sends sensor data.

The **backend** auto-detects the phase by looking at whether the session already has assessment results:
- `assessment_results` present on the row → runs exercise logic (exercise name from `assessment_results.needed_training[0]`)
- `assessment_results` absent → runs assessment logic

This means the firmware never needs to be updated to change the session flow. Flash once and forget.

## Key Constraints

| Constraint | Detail |
|------------|--------|
| No Bluetooth | ESP32 communicates via WiFi only |
| Glove sends continuously | Batches of 100 samples every ~5s to `/ingest` (50ms between samples) |
| No auth | Hardcoded single user, no login screen |
| No multi-patient | This is a one-patient demo |
| No real-time streaming | Glove batches data and POSTs; app polls for results |
| No AI/ML on client | All analysis runs in Lambda (Python scripts) |
| No telehealth | Practitioner mode is read-only, no video calls |

## Data Flow — Patient Session

```
Step 1: Flutter app                    → POST /sessions
         Backend                       → creates session record in DynamoDB
         Flutter app                   ← receives session_id

Step 2: Flutter app links device       → PUT /sessions/{id}/device
         Backend                       → stores device_id in session record

Step 3: Patient puts on glove, flexes hand
         Glove POSTs sensor batches to → POST /ingest  {"device_id": "...", "data": [...]}
         Backend looks up session by device_id
         Backend runs assess_session(data) → writes assessment_results to DynamoDB
         Flutter app polls GET /sessions/{id} every 3s until assessment_results appears

Step 4: Flutter app displays assessment results (PASS/FAIL per function)

Step 5: Flutter app (questionnaire — optional)  → PUT /sessions/{id}/questionnaire
         Backend                                 → stores answers in DynamoDB session record
         (If the patient taps "Skip", no PUT is made and status stays 'assessed'.)

Step 6: Patient exercises with glove on. Optional: Flutter app records video.
         If video: Flutter app         → POST /sessions/{id}/video-upload-url
                   Backend             ← returns presigned S3 PUT URL
                   Flutter app         → PUT video bytes to S3
         Glove keeps POSTing to /ingest — backend sees assessment_results on the
         session row, so it routes this batch to the exercise branch and runs
         run_exercise(data, exercise_name) → writes exercise_results to DynamoDB
         Flutter app polls GET /sessions/{id} every 3s until exercise_results appears

Step 7: Flutter app displays exercise scores
```

## Session State Machine

Observed transitions in a real patient session:

```
created → assessed → exercised
```

`status` is informational only — neither the app nor the ingest router key behavior off it. The app reads `assessment_results` / `exercise_results` on the session row; the ingest Lambda routes on `assessment_results` presence.

`PUT /sessions/{id}/questionnaire` writes the answers object, but because the app always shows the questionnaire *after* assessment, by that time the status is already `assessed` — `save_questionnaire` detects this and leaves status untouched rather than regressing it. (If a client somehow submitted a questionnaire on a `created` session it would flip status to `questionnaire_done`, but no real app path does this today.)

## Polling Strategy

- Poll `GET /sessions/{id}` every 3 seconds
- Timeout after 60 seconds (show error if no result)
- Auto-navigate to results screen when relevant field appears in response
- Simple `Timer.periodic` in Flutter — no WebSockets needed for a demo

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Glove hardware | ESP32 + MPU6050 + flex/FSR/EMG sensors |
| Firmware | Arduino (C++), `firmware/hope_glove/hope_glove.ino` |
| Mobile app | Flutter (Dart), Material 3 |
| State management | Provider (ChangeNotifier) |
| HTTP client | `http` package |
| Video | `camera` + `video_player` packages |
| Backend | AWS Lambda (Python 3.12) |
| Database | DynamoDB (single table) |
| Storage | S3 |
| API | API Gateway REST API |
