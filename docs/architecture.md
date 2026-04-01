# HOPE — Architecture

## What It Is

HOPE is a weekend demo for a smart rehabilitation glove. A patient wears an ESP32-based glove that reads flex sensors, force-sensitive resistors (FSR), an EMG sensor, and an IMU (MPU6050). The system assesses the patient's hand function and scores their rehabilitation exercises. A Flutter app serves as the UI for both patients and practitioners.

## System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│  ESP32 Glove                                                 │
│  Sensors: 2x Flex, 2x FSR, EMG, IMU (MPU6050)              │
│  Firmware: sketch_hope2.ino                                  │
│                                                              │
│  Sends exactly 2 HTTP POSTs per session:                     │
│    POST /sessions/{id}/assess    ← assessment sensor batch   │
│    POST /sessions/{id}/exercise  ← exercise sensor batch     │
└────────────────────┬─────────────────────────────────────────┘
                     │ WiFi (HTTPS)
                     ▼
┌──────────────────────────────────────────────────────────────┐
│  AWS API Gateway (REST)                                      │
│  7 endpoints — see api.md for full contract                  │
└────────────────────┬─────────────────────────────────────────┘
                     │
          ┌──────────┼──────────┐
          ▼          ▼          ▼
   ┌─────────┐ ┌──────────┐ ┌──────────────┐
   │ Lambda  │ │  Lambda  │ │    Lambda    │
   │ session │ │  assess  │ │   exercise   │
   │  _api   │ │          │ │              │
   └────┬────┘ └────┬─────┘ └──────┬───────┘
        │           │              │
        └─────┬─────┘──────────────┘
              ▼
   ┌───────────────────┐     ┌──────────────────┐
   │    DynamoDB       │     │       S3          │
   │  hope-sessions    │     │  Raw sensor data  │
   │  (results, meta)  │     │  Videos           │
   └───────────────────┘     └──────────────────┘
              ▲
              │ polls every 3s
┌─────────────┴────────────────────────────────────────────────┐
│  Flutter App (iOS / Android)                                 │
│                                                              │
│  Patient mode:  6-step session flow                          │
│  Practitioner mode: read-only session history viewer         │
│                                                              │
│  The app NEVER sends sensor data.                            │
│  It only creates sessions, submits questionnaires,           │
│  uploads video, and polls for results.                       │
└──────────────────────────────────────────────────────────────┘
```

## Key Constraints

| Constraint | Detail |
|------------|--------|
| No Bluetooth | ESP32 communicates via WiFi only |
| 2 ESP32 requests max | One POST for assessment, one POST for exercise |
| No auth | Hardcoded single user, no login screen |
| No multi-patient | This is a one-patient demo |
| No real-time streaming | Glove batches data and sends once; app polls for results |
| No AI/ML on client | All analysis runs in Lambda (Python scripts) |
| No telehealth | Practitioner mode is read-only, no video calls |

## Data Flow — Patient Session

```
Step 1: Flutter app                    → POST /sessions
         Backend                       → creates session record in DynamoDB
         Flutter app                   ← receives session_id

Step 2: Flutter app (questionnaire)    → PUT /sessions/{id}/questionnaire
         Backend                       → stores answers in DynamoDB session record

Step 3: Patient puts on glove, flexes hand
         ESP32 buffers sensor data, then  → POST /sessions/{id}/assess
         Lambda                           → runs assess_session(data) from Python script
         Lambda                           → writes assessment_results to DynamoDB
         Flutter app polls GET /sessions/{id} every 3s until assessment_results appears

Step 4: Flutter app displays assessment results (PASS/FAIL per function)

Step 5: Patient exercises with glove on. Optional: Flutter app records video.
         When patient taps "Done":
           If video: Flutter app         → POST /sessions/{id}/video-upload-url
                     Backend             ← returns presigned S3 PUT URL
                     Flutter app         → PUT video bytes to S3
         ESP32 buffers exercise data, then → POST /sessions/{id}/exercise
         Lambda                             → runs run_exercise(data, exercise_name)
         Lambda                             → writes exercise_results to DynamoDB
         Flutter app polls GET /sessions/{id} every 3s until exercise_results appears

Step 6: Flutter app displays exercise scores
```

## Session State Machine

```
created → questionnaire_done → assessed → exercised → completed
```

The `status` field in DynamoDB tracks this. The app uses it to know what data to show.

## Polling Strategy

- Poll `GET /sessions/{id}` every 3 seconds
- Timeout after 60 seconds (show error if no result)
- Auto-navigate to results screen when relevant field appears in response
- Simple `Timer.periodic` in Flutter — no WebSockets needed for a demo

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Glove hardware | ESP32 + MPU6050 + flex/FSR/EMG sensors |
| Firmware | Arduino (C++) |
| Mobile app | Flutter (Dart), Material 3 |
| State management | Provider (ChangeNotifier) |
| HTTP client | `http` package |
| Video | `camera` + `video_player` packages |
| Backend | AWS Lambda (Python 3.12) |
| Database | DynamoDB (single table) |
| Storage | S3 |
| API | API Gateway REST API |
