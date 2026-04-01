# HOPE — Project Documentation

Smart rehabilitation glove demo app. Weekend scope. Single user. No auth.

## Project Structure

```
hope_app/
  flutter_app/        # Flutter mobile app (patient + practitioner UI)
  backend/
    lambdas/
      hope_session_api/   # CRUD Lambda (sessions, questionnaire, video URL)
      hope_assess/         # Assessment Lambda (wraps assesment_hope.py)
      hope_exercise/       # Exercise Lambda (wraps exersisehope.py)
    infra/               # CloudFormation / deployment scripts
  docs/                # This folder — architecture, API, screens, build guide
  storm/               # Original brainstorm files (ESP32 sketch, Python scripts, photos)
```

## Documentation Index

| File | Contents |
|------|----------|
| [architecture.md](./architecture.md) | System overview, data flow, AWS infrastructure |
| [api.md](./api.md) | Full API contract (all 7 endpoints, request/response shapes) |
| [flutter.md](./flutter.md) | Flutter app structure, screens, state management |
| [backend.md](./backend.md) | Lambda functions, DynamoDB schema, S3 layout |
| [build_guide.md](./build_guide.md) | Step-by-step build order from zero to running demo |
