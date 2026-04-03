# HOPE Project — System Architecture

## What This Is

HOPE (Hand Orthosis for Progressive Exercise) is a smart rehabilitation glove system. A physical glove with sensors collects hand movement data, sends it to a cloud backend over **WiFi (HTTP)**, and a mobile app displays assessment and exercise results.

## Three Components

```
┌──────────────┐       WiFi / HTTPS        ┌──────────────────┐
│  ESP32 Glove │ ─────────────────────────► │  AWS Backend     │
│  (firmware)  │   POST /ingest             │  (Lambda + API   │
│              │   {device_id, data:[...]}  │   Gateway +      │
└──────────────┘                            │   DynamoDB + S3) │
                                            └────────┬─────────┘
                                                     │
                                                     │ REST API
                                                     │ (CRUD + polling)
                                            ┌────────┴─────────┐
                                            │  Flutter App      │
                                            │  (iOS / Android)  │
                                            └──────────────────┘
```

## How They Talk

| From → To | Protocol | What |
|-----------|----------|------|
| Glove → Backend | HTTPS POST to `/ingest` | Raw sensor batches (100 samples, 5 sec) |
| App → Backend | HTTPS REST | Session CRUD, polling for results, video upload |
| App → Glove | **NOTHING** | They never communicate directly |

## Critical Design Decisions

1. **The glove is dumb.** It knows nothing about sessions, assessment vs exercise, or results. It just sends `{device_id, data}` over WiFi. The backend figures out everything else.

2. **No Bluetooth.** The glove has WiFi (ESP32) and talks directly to the API Gateway endpoint. The phone app never connects to the glove.

3. **Device linking is server-side.** The app writes a `device_id` string to a session record. When the glove POSTs to `/ingest`, the backend looks up which session has that `device_id` and routes data there.

4. **Polling, not push.** The app polls `GET /sessions/{id}` every 3 seconds waiting for results to appear. No WebSockets, no push notifications.

5. **Single ingest endpoint.** The glove always POSTs to the same `/ingest` URL. The backend checks the session's status to decide whether to run assessment or exercise logic.

## Session Lifecycle

```
created → questionnaire_done → [device linked] → assessed → exercised
   │              │                                  │           │
   │   App: PUT   │  App: PUT /device                │           │
   │   /question. │  (sets device_id on session)     │           │
   │              │                                  │           │
   │              │  Glove: POST /ingest ────────────┘           │
   │              │  (backend runs assess_session)               │
   │              │                                              │
   │              │  Glove: POST /ingest again ──────────────────┘
   │              │  (backend runs run_exercise)
```

## Repository Layout

```
hope_project/
├── ARCHITECTURE.md          ← You are here
├── backend/
│   ├── lambdas/
│   │   ├── hope_session_api/   ← Session CRUD Lambda
│   │   └── hope_ingest/        ← Sensor processing Lambda
│   ├── infra/                  ← Deploy/teardown/cleanup scripts
│   └── tests/                  ← pytest tests (mocked AWS)
├── firmware/
│   └── hope_glove/             ← ESP32 Arduino sketch (WiFi HTTP)
├── flutter_app/                ← Mobile app (iOS/Android)
│   ├── lib/                    ← Dart source code
│   └── docs/                   ← App-specific conventions
├── docs/                       ← Project-wide documentation
└── demo.py                     ← Simulates full session without hardware
```
