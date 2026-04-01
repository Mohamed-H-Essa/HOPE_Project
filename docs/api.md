# HOPE — API Contract

Base URL: `https://<api-gateway-id>.execute-api.eu-west-3.amazonaws.com/prod`

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

**Called by:** Flutter app (Step 2, optional)

```
PUT /sessions/{session_id}/questionnaire
```

**Request body:**
```json
{
  "answers": {
    "pain_level": 4,
    "stiffness": true,
    "comments": "Feeling better than last week"
  }
}
```

**Response 200:**
```json
{
  "status": "questionnaire_done"
}
```

---

## 3. Submit Assessment Sensor Data

**Called by:** ESP32 (not the Flutter app)

```
POST /sessions/{session_id}/assess
```

**Request body:** Raw sensor array (collected over ~5-10 seconds)
```json
[
  {
    "time": 1000,
    "flex1": 45, "flex2": 38,
    "fsr1": 62, "fsr2": 55,
    "emg": 340,
    "ax": 1024, "ay": -512, "az": 16384,
    "gx": 100, "gy": -50, "gz": 30
  },
  { ... },
  ...
]
```

**Response 200:**
```json
{
  "session_id": "550e8400-...",
  "assessment_results": {
    "Reach": "PASS",
    "Grasp": "FAIL",
    "Manipulation": "PASS",
    "Release": "FAIL",
    "needed_training": ["Grasp", "Release"]
  },
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

---

## 4. Submit Exercise Sensor Data

**Called by:** ESP32 (not the Flutter app)

```
POST /sessions/{session_id}/exercise
```

**Request body:**
```json
{
  "data": [
    {
      "time": 1000,
      "flex1": 45, "flex2": 38,
      "fsr1": 62, "fsr2": 55,
      "emg": 340,
      "ax": 1024, "ay": -512, "az": 16384,
      "gx": 100, "gy": -50, "gz": 30
    },
    { ... }
  ],
  "exercise": "Grasp"
}
```

Valid `exercise` values: `"Reach"`, `"Grasp"`, `"Manipulation"`, `"Release"`

**Response 200:**
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

---

## 5. Get Video Upload URL

**Called by:** Flutter app (Step 5, optional — only if patient recorded video)

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
        "failed": 2,
        "needed_training": ["Grasp", "Release"]
      },
      "exercise_overall_percent": 70.2
    },
    { ... }
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
  "questionnaire": {
    "pain_level": 4,
    "stiffness": true,
    "comments": "Feeling better than last week"
  },
  "assessment_results": {
    "Reach": "PASS",
    "Grasp": "FAIL",
    "Manipulation": "PASS",
    "Release": "FAIL",
    "needed_training": ["Grasp", "Release"]
  },
  "assessment_features": {
    "speed": 2.14,
    "rom": 67.3,
    "trajectory": 0.88,
    "deviation": 1450.2,
    "flex": 41.5,
    "force": 58.9,
    "emg": 312.7
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
- `404` — session not found
- `500` — internal server error (Lambda exception)
