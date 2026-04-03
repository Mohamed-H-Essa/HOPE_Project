# HOPE — Project Documentation

Smart rehabilitation glove demo app. Weekend scope. Single user. No auth.

## Project Structure

```
hope_project/
  firmware/
    hope_glove/             # ESP32 firmware (.ino) — dumb data pipe
  flutter_app/              # Flutter mobile app (patient + practitioner UI)
  backend/
    lambdas/
      hope_session_api/     # CRUD Lambda (sessions, questionnaire, video URL, device linking)
      hope_ingest/          # Unified ingest Lambda (auto-detects assess vs exercise)
    infra/                  # deploy.sh, teardown.sh, cleanup.sh
    tests/                  # Unit tests (moto mocks)
  docs/                     # This folder — architecture, API, screens, build guide
  demo.py                   # End-to-end demo script (simulates full session flow)
```

## Documentation Index

| File | Contents |
|------|----------|
| [architecture.md](./architecture.md) | System overview, data flow, AWS infrastructure |
| [api.md](./api.md) | Full API contract (all endpoints, request/response shapes) |
| [flutter.md](./flutter.md) | Flutter app structure, screens, state management |
| [backend.md](./backend.md) | Lambda functions, DynamoDB schema, S3 layout |
| [build_guide.md](./build_guide.md) | Step-by-step build order from zero to running demo |
