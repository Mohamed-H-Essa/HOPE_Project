# HOPE Flutter App — API Contract

## Base URL

```
https://unj4s6yf6b.execute-api.us-east-1.amazonaws.com/prod
```

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

**Response** (200): Empty

### PUT /sessions/{id}/device

Link a glove device to the session.

**Request**:
```json
{
  "device_id": "hope-glove-01"
}
```

**Response** (200): Empty

### GET /sessions/{id}

Get full session details.

**Response** (200):
```json
{
  "session_id": "uuid-string",
  "created_at": "2026-04-03 14:30:00",
  "status": "completed",
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
    "reach_range": "85.2",
    "grasp_force": "42.1"
  },
  "exercise_results": {
    "exercise": "Grasp",
    "features": {
      "force": 72.5,
      "flex": 68.0
    },
    "overall_percent": 70.2,
    "message": "Good work! Keep practicing.",
    "timestamp": "2026-04-03 14:45:32"
  },
  "video_url": "https://presigned-s3-url..."
}
```

### GET /sessions

List all sessions (for practitioner).

**Response** (200):
```json
{
  "sessions": [
    {
      "session_id": "uuid-string",
      "created_at": "2026-04-03 14:30:00",
      "status": "completed",
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

### GET /sessions/{id}/video-upload-url

Get a presigned S3 URL for video upload.

**Response** (200):
```json
{
  "upload_url": "https://bucket.s3.amazonaws.com/videos/uuid.mp4?..."
}
```

## Endpoints Used by Glove (NOT by App)

### POST /ingest

The ESP32 glove sends sensor data here. The app never calls this endpoint.

## Status Values

- `created` — Session just created
- `in_progress` — Device linked, assessment pending
- `assessment_done` — Assessment complete, exercise pending
- `completed` — Exercise complete

## Presigned URL Mechanics

- **Upload**: `PUT` to presigned URL with `Content-Type: video/mp4`
- **Download**: `video_url` in session response is already a presigned GET URL
- **Expiry**: URLs expire after a set time (configured in backend)
