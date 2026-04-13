# HOPE Backend — Infrastructure Guide

## TL;DR

**Check state:** run `audit.sh` — read-only inventory, flags orphans, reports cost. Exit 0 = clean.
**Between demos:** run `cleanup.sh` — wipes data, keeps infra alive, costs nothing, URL unchanged.
**Done forever:** run `teardown.sh` — destroys everything (URL will change on next deploy).
**Fresh deploy:** run `deploy.sh` — builds everything from scratch, prints new URL and smoke-tests.

---

## Actual AWS Costs

This stack is essentially free at demo scale.

| Service | Cost at rest | Cost per demo session |
|---------|-------------|----------------------|
| API Gateway REST | **$0** (pay per request) | ~$0.00001 |
| Lambda (2 functions) | **$0** (1M free req/month) | **$0** |
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
1. Update `INGEST_URL` in `firmware/hope_glove/hope_glove.ino` and reflash the ESP32
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
- Deletes both Lambda functions (`hope_session_api`, `hope_ingest`)
- Deletes API Gateway REST API
- Deletes IAM role + policies

What breaks: **URL changes on next deploy. ESP32 firmware must be reflashed.**

```bash
./backend/infra/teardown.sh
```

### `deploy.sh` — fresh deploy from scratch

What it does:
- Creates IAM role
- Creates DynamoDB table
- Creates S3 bucket (with CORS for video uploads) — **see S3 Bucket Region note below**
- Packages and deploys both Lambda functions
- Creates API Gateway with all routes
- Deploys to `prod` stage
- Prints the new base URL
- Smoke-tests `GET /sessions` and warns on non-200

```bash
REGION=us-east-1 ./backend/infra/deploy.sh
```

After a fresh deploy, update:
1. `firmware/hope_glove/hope_glove.ino` → `INGEST_URL` (base URL + `/ingest`)
2. `flutter_app/lib/config.dart` → `AppConfig.apiBaseUrl`

### `audit.sh` — read-only inventory + orphan detector

What it does:
- Lists every `hope*` resource and compares to the canonical set defined in `deploy.sh`
- Flags orphans (anything live that isn't in the canonical set) with the exact delete command
- Shows DynamoDB item count, S3 bucket region + object count, IAM role, log groups
- Reports cost for the last 7 days by service
- Exit code 0 = clean, 1 = orphans found

```bash
./backend/infra/audit.sh                # audit primary region only
ALL_REGIONS=1 ./backend/infra/audit.sh  # also scan other common AWS regions
```

## S3 Bucket Region (known exception)

Everything lives in `us-east-1` **except** the S3 bucket `hope-data-321209672840`, which is in `eu-west-3` (Paris). It was created out-of-band before the first infra deploy and we've kept it there intentionally — the cross-region hop from the us-east-1 Lambdas adds ~100-150 ms per S3 PUT/GET and a tiny data-transfer cost, both negligible at current scale.

`audit.sh` knows about this and prints an informational NOTE rather than flagging it as an orphan. `deploy.sh` does not re-create this bucket (it only runs `create-bucket` if the bucket doesn't exist yet), so re-running it is safe.

If you ever do want to collapse to a single region, the migration is straightforward:

```bash
# 1. Sync objects to a new us-east-1 bucket
aws s3 sync s3://hope-data-321209672840 s3://hope-data-321209672840-new \
  --source-region eu-west-3 --region us-east-1

# 2. Swap bucket names (rename the new bucket by syncing one more time into a bucket
#    with the canonical name created via deploy.sh after deleting the Paris one)

# 3. Restart the Lambdas so the updated HOPE_BUCKET env var takes effect
```

Not on any roadmap — only listed here so the inconsistency is explainable when someone inevitably asks.

---

## After Cleanup — Verify Nothing Is Broken

```bash
BASE="https://<your-api-id>.execute-api.us-east-1.amazonaws.com/prod"
curl -s "$BASE/sessions" | python3 -m json.tool
# Expected: {"sessions": []}
```

---

## After Full Teardown + Redeploy — Update These Two Places

1. **ESP32 firmware** (`firmware/hope_glove/hope_glove.ino`):
   ```cpp
   const char* INGEST_URL = "https://<new-api-id>.execute-api.us-east-1.amazonaws.com/prod/ingest";
   ```

2. **Flutter app** (`flutter_app/lib/config.dart`):
   ```dart
   static const String apiBaseUrl =
       'https://<new-api-id>.execute-api.us-east-1.amazonaws.com/prod';
   ```
