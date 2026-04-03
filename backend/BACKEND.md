# HOPE Backend

## Overview

Two AWS Lambda functions behind API Gateway, with DynamoDB for session state and S3 for sensor data + video storage.

## The Two Lambdas

### `hope_session_api` — Session CRUD

Called by the **Flutter app only**. Handles session lifecycle management.

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/sessions` | Create new session |
| GET | `/sessions` | List all sessions with summaries |
| GET | `/sessions/{id}` | Get full session detail (includes presigned video URL) |
| PUT | `/sessions/{id}/questionnaire` | Save patient questionnaire answers |
| PUT | `/sessions/{id}/device` | Link a device_id to the session |
| POST | `/sessions/{id}/video-upload-url` | Get presigned S3 PUT URL for video upload |

### `hope_ingest` — Sensor Data Processing

Called by the **ESP32 glove only**. Single endpoint that handles both assessment and exercise.

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/ingest` | Accept sensor batch, run assessment or exercise logic |

**Routing logic inside `/ingest`:**
1. Extract `device_id` from request body
2. Scan DynamoDB for active session with that `device_id` (status != 'completed')
3. If session status is `assessed` → run exercise logic
4. Otherwise → run assessment logic
5. Store raw sensor data in S3, update session with results

## How the Glove Finds Its Session

The glove sends `{device_id: "hope-glove-01", data: [...]}`. It does NOT send a session ID.

The backend scans DynamoDB: "Find session WHERE device_id = 'hope-glove-01' AND status is active." This is why device linking must happen before the glove's data can be processed.

## DynamoDB Schema

**Table:** `hope-sessions` (on-demand billing)
**Partition key:** `session_id` (String, UUID)

| Field | Type | Set By |
|-------|------|--------|
| `session_id` | String | POST /sessions |
| `created_at` | String | POST /sessions |
| `status` | String | Various (see lifecycle) |
| `device_id` | String | PUT /device |
| `questionnaire` | Map | PUT /questionnaire |
| `assessment_results` | Map | POST /ingest (assess phase) |
| `assessment_features` | Map | POST /ingest (assess phase) |
| `exercise_results` | Map | POST /ingest (exercise phase) |
| `sensor_data_assess_s3` | String | POST /ingest (assess phase) |
| `sensor_data_exercise_s3` | String | POST /ingest (exercise phase) |
| `video_s3_key` | String | POST /video-upload-url |

### Status Values

```
created → questionnaire_done → assessed → exercised
```

- `created`: Session exists, nothing else done
- `questionnaire_done`: Patient filled in the survey
- `assessed`: Assessment sensor data processed, results available
- `exercised`: Exercise sensor data processed, results available

Note: Device linking does NOT change status. It only sets `device_id`.

## S3 Layout

```
hope-data-{account-id}/
├── sensor-data/{session_id}/
│   ├── assess.json       ← Raw sensor batch from assessment
│   └── exercise.json     ← Raw sensor batch from exercise
└── videos/{session_id}/
    └── video.mp4         ← Patient-recorded video (optional)
```

## Assessment Logic (`assess_logic.py`)

Extracts 7 features from raw sensor data, runs 4 pass/fail tests:

| Function | Pass Criteria |
|----------|--------------|
| Reach | ROM > 60 AND speed between 1-3 AND trajectory > 0.85 AND deviation < 2000 |
| Grasp | Force > 50 AND flex > 40 |
| Manipulation | Trajectory > 0.8 AND duration < 6s |
| Release | Force < 20 AND flex < 20 |

Output: `{Reach: PASS, Grasp: FAIL, ..., needed_training: [Grasp, Release]}`

## Exercise Logic (`exercise_logic.py`)

Scores the patient on the first exercise from `needed_training`. Each exercise type scores different features on a 0-100 scale.

Output: `{exercise: "Grasp", features: {force: 72.5, flex: 68.0}, overall_percent: 70.2, message: "Good work!"}`

## Testing

```bash
cd backend && python -m pytest tests/ -v
```

Tests use `moto` to mock AWS services. No real AWS calls needed.
