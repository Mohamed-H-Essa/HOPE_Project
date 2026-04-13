# HOPE — API Contract

Base URL: `https://<api-gateway-id>.execute-api.us-east-1.amazonaws.com/prod`

Defined in `flutter_app/lib/config.dart` as a single constant.

All endpoints return `Content-Type: application/json`. CORS enabled on all routes (no auth).

---

## 1. Create Session

**Called by:** Flutter app (Step 1)

```
POST /sessions
```

**Request body:** none

**Response 201:**
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "created_at": "2026-04-01T10:00:00Z",
  "status": "created"
}
```

---

## 2. Save Questionnaire

**Called by:** Flutter app, optional, AFTER the assessment phase (between `AssessmentResultsScreen` and `ExerciseWaitingScreen`). The Skip button in the app's AppBar submits no request — it's a pure UI transition.

```
PUT /sessions/{session_id}/questionnaire
```

**Request body** — the 10-question daily check-in. Keys and value shapes are defined by `flutter_app/lib/screens/patient/questionnaire_screen.dart:18-39` (source of truth):

```json
{
  "sleep_hours": 7.5,
  "body_temperature": 37.0,
  "blood_sugar": 100,
  "blood_pressure": {"systolic": 120, "diastolic": 80},
  "headache": false,
  "dizzy": false,
  "fatigue": true,
  "arm_pain": 3,
  "hand_movement": true,
  "falls_injuries": false
}
```

Field reference:

| Key | Type | Units / range |
|---|---|---|
| `sleep_hours` | number | hours, 0–14, 0.5 step |
| `body_temperature` | number | °C, 34–42, 0.1 step |
| `blood_sugar` | integer | mg/dL, 40–400 |
| `blood_pressure` | `{systolic:int, diastolic:int}` | mm Hg |
| `headache` | bool | yes/no |
| `dizzy` | bool | yes/no |
| `fatigue` | bool | yes/no |
| `arm_pain` | integer | 0–10 pain scale |
| `hand_movement` | bool | yes/no — "able to move your hand today as usual" |
| `falls_injuries` | bool | yes/no — "any falls or injuries since last session" |

The backend also accepts a wrapped form `{"answers": {...}}` for backwards compatibility (`handler.py:64`: `body.get('answers', body)`), but the app sends the raw object.

**Note on numeric round-trip:** DynamoDB stores numbers as arbitrary-precision `Decimal`. The `GET /sessions/{id}` response re-serializes them as JSON floats via `_DecimalEncoder` in `handler.py`, so integer inputs (e.g. `"systolic": 120`) may come back as floats (`120.0`). Clients should parse numeric questionnaire fields loosely.

**Response 200:**
```json
{
  "status": "assessed"
}
```

The `status` field echoes the session's current lifecycle status *after* the write. In the normal app flow the questionnaire is submitted after assessment, so the response is `"assessed"`. If a questionnaire is submitted before assessment (no current app path does this), the response is `"questionnaire_done"`.

---

## 3. Link Device to Session

**Called by:** Flutter app (before glove starts sending data)

```
PUT /sessions/{session_id}/device
```

**Request body:**
```json
{
  "device_id": "hope-glove-01"
}
```

**Response 200:**
```json
{
  "status": "device_linked",
  "device_id": "hope-glove-01"
}
```

This tells the backend which session the glove's data belongs to. The glove itself only knows its own `device_id` — it never learns about session IDs.

---

## 4. Ingest Sensor Data (unified endpoint)

**Called by:** ESP32 glove (continuously, every ~5 seconds)

```
POST /ingest
```

**Request body:**
```json
{
  "device_id": "hope-glove-01",
  "data": [
    {
      "time": 19136,
      "flex1": 45, "flex2": 38,
      "fsr1": 62, "fsr2": 55,
      "emg": 340,
      "ax": 1024, "ay": -512, "az": 16384,
      "gx": 100, "gy": -50, "gz": 30
    },
    ...99 more samples at 50ms intervals (total ~5 seconds)
  ]
}
```

Canonical field schema (types, ranges, units) lives in [`firmware/FIRMWARE.md`](../firmware/FIRMWARE.md#sensors). Highlights: `time` is `millis()` since boot (not reset per batch); `fsr` is 0 = no force, 100 = max; `emg` is `abs(raw−2000)×2` (not raw ADC); IMU values are raw MPU6050 int16 LSB at ±2g / ±250°/s.

The glove is a dumb data pipe — it sends only `device_id` and raw sensor samples.
It has **no knowledge** of sessions, modes, or exercise names. The body must
contain **only** `device_id` and `data` — no `type` or `phase` field.

The backend auto-detects the phase by inspecting the linked session row:
- `assessment_results` already present → runs exercise logic (exercise name from `assessment_results.needed_training[0]`)
- `assessment_results` absent → runs assessment logic

**Response 200 (assessment):**
```json
{
  "session_id": "550e8400-...",
  "assessment_results": {
    "Reach": true,
    "Grasp": false,
    "Manipulation": true,
    "Release": false
  },
  "needed_training": ["Grasp", "Release"],
  "features": {
    "speed": 2.14,
    "rom": 67.3,
    "trajectory": 0.88,
    "deviation": 1450.2,
    "flex": 41.5,
    "force": 58.9,
    "emg": 312.7
  },
  "status": "assessed"
}
```

**Response 200 (exercise):**
```json
{
  "session_id": "550e8400-...",
  "exercise_results": {
    "exercise": "Grasp",
    "features": {
      "force": 72.5,
      "flex": 68.0
    },
    "overall_percent": 70.2,
    "message": "Good work! You're improving",
    "timestamp": "2026-04-01 10:15:32"
  },
  "status": "exercised"
}
```

**Response 404:** No active session linked to this device.

---

## 5. Get Video Upload URL

**Called by:** Flutter app (optional — only if patient recorded video)

```
POST /sessions/{session_id}/video-upload-url
```

**Request body:** none

**Response 200:**
```json
{
  "upload_url": "https://hope-data-<account>.s3.amazonaws.com/videos/<session_id>/video.mp4?X-Amz-Signature=...",
  "s3_key": "videos/<session_id>/video.mp4",
  "expires_in": 600
}
```

The Flutter app then does an HTTP `PUT` to `upload_url` with the raw video bytes and `Content-Type: video/mp4`. No auth headers needed on the S3 request itself — the presigned URL handles that.

---

## 6. List Sessions

**Called by:** Flutter app (Practitioner mode — session list screen)

```
GET /sessions
```

**Response 200:**
```json
{
  "sessions": [
    {
      "session_id": "550e8400-...",
      "created_at": "2026-04-01T10:00:00Z",
      "status": "exercised",
      "assessment_summary": {
        "passed": 2,
        "total": 4,
        "needed_training": ["Grasp", "Release"]
      },
      "exercise_overall_percent": 70.2
    }
  ]
}
```

---

## 7. Get Session Detail

**Called by:** Flutter app (Practitioner mode — session detail screen, also used for polling in patient mode)

```
GET /sessions/{session_id}
```

**Response 200 (full session record):**
```json
{
  "session_id": "550e8400-...",
  "created_at": "2026-04-01T10:00:00Z",
  "status": "exercised",
  "device_id": "hope-glove-01",
  "questionnaire": {
    "sleep_hours": 7.5,
    "body_temperature": 37.0,
    "blood_sugar": 100,
    "blood_pressure": {"systolic": 120, "diastolic": 80},
    "headache": false,
    "dizzy": false,
    "fatigue": true,
    "arm_pain": 3,
    "hand_movement": true,
    "falls_injuries": false
  },
  "assessment_results": {
    "Reach": "PASS",
    "Grasp": "FAIL",
    "Manipulation": "PASS",
    "Release": "FAIL",
    "needed_training": ["Grasp", "Release"]
  },
  "assessment_features": {
    "speed": "2.14",
    "rom": "67.3",
    "trajectory": "0.88",
    "deviation": "1450.2",
    "flex": "41.5",
    "force": "58.9",
    "emg": "312.7"
  },
  "exercise_results": {
    "exercise": "Grasp",
    "features": {
      "force": 72.5,
      "flex": 68.0
    },
    "overall_percent": 70.2,
    "message": "Good work! You're improving",
    "timestamp": "2026-04-01 10:15:32"
  },
  "video_url": "https://hope-data-<account>.s3.amazonaws.com/videos/<session_id>/video.mp4?X-Amz-Signature=..."
}
```

Notes:
- `questionnaire`, `assessment_results`, `exercise_results` are `null` if not yet completed
- `video_url` is a presigned GET URL valid for 1 hour, or `null` if no video
- **Polling:** The Flutter app uses this endpoint to detect when the ESP32 has finished sending data. It checks for the presence of `assessment_results` or `exercise_results`.

---

## Error Responses

All errors follow the same shape:

```json
{
  "error": "session_not_found",
  "message": "No session found with id 550e8400-..."
}
```

Common HTTP status codes:
- `400` — bad request (missing required fields)
- `404` — session not found / no active session for device
- `500` — internal server error (Lambda exception)
