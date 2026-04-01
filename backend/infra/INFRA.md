# HOPE Backend — Infrastructure Guide

## TL;DR

**Between demos:** run `cleanup.sh` — wipes data, keeps infra alive, costs nothing, URL unchanged.
**Done forever:** run `teardown.sh` — destroys everything (URL will change on next deploy).
**Fresh deploy:** run `deploy.sh` — builds everything from scratch, prints new URL.

---

## Actual AWS Costs

This stack is essentially free at demo scale.

| Service | Cost at rest | Cost per demo session |
|---------|-------------|----------------------|
| API Gateway REST | **$0** (pay per request) | ~$0.00001 |
| Lambda (3 functions) | **$0** (1M free req/month) | **$0** |
| DynamoDB on-demand | **$0** (pay per write) | ~$0.00001 |
| CloudWatch Logs | **$0** (5 GB free) | **$0** |
| S3 storage | ~$0.001/month per 40 MB of video | ~$0.001 per video |

**The only real cost is S3 video storage.** A session video (~50 MB) costs about $0.001/month to store. Running `cleanup.sh` after a demo deletes those objects — monthly bill is effectively $0.

---

## The URL Problem

API Gateway assigns a random ID when you first create an API:
```
https://abc123xyz.execute-api.us-east-1.amazonaws.com/prod
```

If you **destroy and recreate** API Gateway, you get a new random ID and the ESP32 firmware breaks.

**Solution: never destroy API Gateway.** It costs $0 at rest. Only wipe data between demos.

If you ever do need a full teardown + redeploy (e.g., switching regions), you must:
1. Update `serverName` in the ESP32 sketch and reflash the board
2. Update `AppConfig.apiBaseUrl` in `flutter_app/lib/config.dart`

---

## The Three Scripts

### `cleanup.sh` — use this between demos

What it does:
- Deletes all objects from S3 bucket (sensor data + videos)
- Deletes all items from DynamoDB table
- Does **NOT** touch Lambda, API Gateway, or IAM

What breaks: nothing. URL stays the same. Infra stays live.
What it costs to leave running after cleanup: $0.

```bash
./backend/infra/cleanup.sh
```

### `teardown.sh` — use only when done with the project

What it does:
- Deletes all S3 objects, then deletes the bucket
- Deletes DynamoDB table
- Deletes all 3 Lambda functions
- Deletes API Gateway REST API
- Deletes IAM role + policies

What breaks: **URL changes on next deploy. ESP32 firmware must be updated.**

```bash
./backend/infra/teardown.sh
```

### `deploy.sh` — fresh deploy from scratch

What it does:
- Creates IAM role
- Creates DynamoDB table
- Creates S3 bucket
- Packages and deploys all 3 Lambda functions
- Creates API Gateway with all 7 routes
- Deploys to `prod` stage
- Prints the new base URL

```bash
REGION=us-east-1 ./backend/infra/deploy.sh
```

After a fresh deploy, update `AppConfig.apiBaseUrl` in `flutter_app/lib/config.dart` with the printed URL.

---

## After Cleanup — Verify Nothing Is Broken

```bash
BASE="https://<your-api-id>.execute-api.<region>.amazonaws.com/prod"
curl -s "$BASE/sessions" | python3 -m json.tool
# Expected: {"sessions": []}
```

---

## After Full Teardown + Redeploy — Update These Two Places

1. **ESP32 firmware** (`storm/storm/sketch_hope2.ino`):
   ```cpp
   const char* serverName = "https://<new-api-id>.execute-api.<region>.amazonaws.com/prod";
   ```

2. **Flutter app** (`flutter_app/lib/config.dart`):
   ```dart
   static const String apiBaseUrl =
       'https://<new-api-id>.execute-api.<region>.amazonaws.com/prod';
   ```
