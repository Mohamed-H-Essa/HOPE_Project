# HOPE — Progress Log

## Backend Deployment — 2026-04-01

### What's deployed

| Resource | Name | Region |
|----------|------|--------|
| API Gateway | `hope-api` | eu-west-3 |
| Lambda | `hope_session_api` | eu-west-3 |
| Lambda | `hope_assess` | eu-west-3 |
| Lambda | `hope_exercise` | eu-west-3 |
| DynamoDB | `hope-sessions` | eu-west-3 |
| S3 | `hope-data-321209672840` | eu-west-3 |
| IAM Role | `hope-lambda-role` | — |

### API Base URL (permanent)

```
https://wsrk7wste5.execute-api.eu-west-3.amazonaws.com/prod
```

### Endpoints (all verified working)

| Method | Path | Lambda |
|--------|------|--------|
| POST | `/sessions` | hope_session_api |
| GET | `/sessions` | hope_session_api |
| GET | `/sessions/{session_id}` | hope_session_api |
| PUT | `/sessions/{session_id}/questionnaire` | hope_session_api |
| POST | `/sessions/{session_id}/assess` | hope_assess |
| POST | `/sessions/{session_id}/exercise` | hope_exercise |
| POST | `/sessions/{session_id}/video-upload-url` | hope_session_api |

### Test results

- **Unit tests:** 71/71 passed (moto mocks, no AWS credentials needed)
- **Smoke tests:** All 7 endpoints return expected JSON against live AWS

### Bugs fixed during deploy

1. **Lambda race condition:** `deploy.sh` called `update-function-configuration` immediately after `create-function` / `update-function-code`, before the Lambda was ready. Fixed by adding a stabilization wait loop.
2. **Env var mismatch:** Deploy script set `BUCKET=...` but handlers read `HOPE_BUCKET`. Fixed deploy script to set `HOPE_BUCKET`.

### URL stability

The API URL **does not change** between these operations:

- Re-running `deploy.sh` — reuses existing API ID
- Running `cleanup.sh` — only wipes DynamoDB + S3 data

The URL **will change** if you run `teardown.sh` (destroys API Gateway).

**For ESP32:** Flash once with the URL above. Between demo sessions, run `cleanup.sh` to reset data. Never run `teardown.sh`.

### Cost

At demo scale (a few sessions): ~$0/month. DynamoDB and Lambda are pay-per-request. S3 storage is negligible.

### Quick reference

```bash
# Deploy (or update) backend
REGION=eu-west-3 ./backend/infra/deploy.sh

# Reset data between demos (URL survives)
./backend/infra/cleanup.sh

# Full teardown (URL changes on next deploy)
./backend/infra/teardown.sh

# Run tests
cd backend && pytest tests/ -v
```
