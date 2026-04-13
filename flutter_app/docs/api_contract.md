# HOPE Flutter App — API Contract

## Base URL

```
https://unj4s6yf6b.execute-api.us-east-1.amazonaws.com/prod
```

## Key Concept: App vs Glove

The app and the glove talk to the SAME backend but use DIFFERENT endpoints:

- **App calls:** `/sessions` (CRUD), `/sessions/{id}` (polling), `/sessions/{id}/device`, etc.
- **Glove calls:** `/ingest` (sensor data batches over WiFi)
- **They never talk to each other.** The backend links them via `device_id`.

## Endpoints Used by App

### POST /sessions

Create a new session.

**Request**: Empty body

**Response** (201):
```json
{
  "session_id": "uuid-string",
  "created_at": "2026-04-03 14:30:00",
  "status": "created"
}
```

### PUT /sessions/{id}/questionnaire

Submit questionnaire answers.

**Request**:
```json
{
  "pain_level": 5,
  "stiffness": true,
  "comments": "Feeling okay today",
  "goal": "Improve grip"
}
```

**Response** (200): `{"status": "questionnaire_done"}`

### PUT /sessions/{id}/device

Link a device_id to the session. This is NOT a Bluetooth pairing — it's just
writing a string to the database so the backend knows which session to route
the glove's sensor data to.

**Request**:
```json
{
  "device_id": "hope-glove-01"
}
```

**Response** (200): `{"status": "...", "device_id": "hope-glove-01"}`

### GET /sessions/{id}

Get full session details. The app polls this endpoint every 3s to detect when
the glove's data has been processed.

**Response** (200):
```json
{
  "session_id": "uuid-string",
  "created_at": "2026-04-03 14:30:00",
  "status": "assessed",
  "device_id": "hope-glove-01",
  "questionnaire": {
    "pain_level": 5,
    "stiffness": true,
    "comments": "Feeling okay today",
    "goal": "Improve grip"
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
    "timestamp": "2026-04-03 14:45:32"
  },
  "video_url": "https://presigned-s3-get-url..."
}
```

Fields appear incrementally as the session progresses. `assessment_results` is
null until the glove sends assessment data. `exercise_results` is null until
the glove sends exercise data.

### GET /sessions

List all sessions (for practitioner view).

**Response** (200):
```json
{
  "sessions": [
    {
      "session_id": "uuid-string",
      "created_at": "2026-04-03 14:30:00",
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

### POST /sessions/{id}/video-upload-url

Get a presigned S3 URL for video upload (10-minute expiry).

**Request**: Empty body

**Response** (200):
```json
{
  "upload_url": "https://bucket.s3.amazonaws.com/videos/uuid/video.mp4?...",
  "s3_key": "videos/uuid/video.mp4",
  "expires_in": 600
}
```

## Endpoints Used by Glove (and Simulated by App's Debug Button)

### POST /ingest

The ESP32 glove sends raw sensor batches here over WiFi. In production the app
never calls this; the debug "Simulate Glove" button on the waiting screens calls
it to simulate the glove locally during development/demo.

**Request body:**
```json
{
  "device_id": "hope-glove-01",
  "data": [
    {"time": 19136, "flex1": 45, "flex2": 38, "fsr1": 62, "fsr2": 55, "emg": 340,
     "ax": 1024, "ay": -512, "az": 16384, "gx": 100, "gy": -50, "gz": 30},
    ... (99 more samples at 50ms intervals)
  ]
}
```

The payload is **only** `device_id` + `data`. No `type` or `phase` field. The
backend auto-detects assessment vs exercise from the session's status:
- `status == 'assessed'` → runs exercise logic
- anything else → runs assessment logic

**Sensor ranges.** Canonical table lives in [`firmware/FIRMWARE.md`](../../firmware/FIRMWARE.md#sensors); reproduced here for convenience.

| Field | Range | Units | Notes |
|-------|-------|-------|-------|
| `time` | `millis()` since boot (monotonic) | ms | **Not** reset per batch. Samples ~50 ms apart. |
| `flex1`, `flex2` | 0–90 | degrees | Finger bend angle |
| `fsr1`, `fsr2` | 0–100 | percent | Grip force. **0 = no force, 100 = max** |
| `emg` | ~0–4000 | rectified magnitude | `abs(raw−2000)×2`, not raw ADC |
| `ax`, `ay`, `az` | ±32768 LSB | raw | MPU6050 ±2g (16384 LSB/g); `az` ≈ 16384 at rest |
| `gx`, `gy`, `gz` | ±32768 LSB | raw | MPU6050 ±250°/s (131 LSB per °/s) |

## Status Values (Actual Backend Values)

- `created` — Session exists, nothing submitted yet
- `questionnaire_done` — Patient questionnaire saved
- `assessed` — Glove sent assessment data, results computed
- `exercised` — Glove sent exercise data, results computed

Note: Device linking does NOT change the status value. It only sets `device_id`.

## Presigned URL Mechanics

- **Upload**: `PUT` to presigned URL with `Content-Type: video/mp4` (10-min expiry)
- **Download**: `video_url` in GET /sessions/{id} response is a presigned GET URL (1-hour expiry)
