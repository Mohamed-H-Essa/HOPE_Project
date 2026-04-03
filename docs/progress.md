# HOPE — Progress Log

## Backend Deployment — 2026-04-01

### What's deployed

| Resource | Name | Region |
|----------|------|--------|
| API Gateway | `hope-api` | us-east-1 |
| Lambda | `hope_session_api` | us-east-1 |
| Lambda | `hope_ingest` | us-east-1 |
| DynamoDB | `hope-sessions` | us-east-1 |
| S3 | `hope-data-{account-id}` | us-east-1 |
| IAM Role | `hope-lambda-role` | — |

### Endpoints (all verified working)

| Method | Path | Lambda |
|--------|------|--------|
| POST | `/sessions` | hope_session_api |
| GET | `/sessions` | hope_session_api |
| GET | `/sessions/{session_id}` | hope_session_api |
| PUT | `/sessions/{session_id}/questionnaire` | hope_session_api |
| PUT | `/sessions/{session_id}/device` | hope_session_api |
| POST | `/sessions/{session_id}/video-upload-url` | hope_session_api |
| POST | `/ingest` | hope_ingest |

### Architecture changes (2026-04-02)

- **Unified ingest endpoint:** Replaced separate `hope_assess` and `hope_exercise` lambdas with a single `hope_ingest` lambda. The backend auto-detects assess vs exercise from the session's status.
- **Dumb glove design:** ESP32 firmware (`firmware/hope_glove/hope_glove.ino`) sends only `device_id` + raw sensor data. No knowledge of sessions, modes, or exercise names.
- **Device linking:** Added `PUT /sessions/{id}/device` to bind a device to a session. The `/ingest` endpoint uses this to find the correct session.

### URL stability

The API URL **does not change** between these operations:

- Re-running `deploy.sh` — reuses existing API ID
- Running `cleanup.sh` — only wipes DynamoDB + S3 data

The URL **will change** if you run `teardown.sh` (destroys API Gateway).

**For ESP32:** Flash once with the URL. Between demo sessions, run `cleanup.sh` to reset data. Never run `teardown.sh`.

### Quick reference

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
