# HOPE Flutter App

## What This App Does

Mobile companion for the HOPE rehabilitation glove. Two modes:

- **Patient mode**: Linear flow — create session → link device → wait for assessment → view results → questionnaire → wait for exercise → view scores
- **Practitioner mode**: Read-only session history viewer with assessment/exercise/video tabs

## What This App Does NOT Do

- **Does NOT connect to the glove.** There is no Bluetooth. The glove connects to the backend over WiFi independently.
- **Does NOT call `/ingest` in the normal patient flow.** The debug "Simulate Glove" button is the only exception — it mimics the glove during development. In a real deployment the glove handles all `/ingest` traffic.
- **Does NOT process sensor data.** All assessment/exercise logic runs server-side in Lambda.

## How It Works

```
1. App creates a session (POST /sessions)
2. App links a device_id string to the session (PUT /sessions/{id}/device)
3. Glove independently sends sensor data to the backend over WiFi
4. Backend matches glove's device_id to the session, processes data
5. App polls GET /sessions/{id} every 3s until results appear
6. App displays results
```

## Project Structure

```
lib/
  main.dart                           # App entry point + Provider setup
  config.dart                         # API base URL + default device ID

  models/
    session.dart                      # Session + SessionSummary
    assessment_result.dart            # 4x PASS/FAIL function results
    exercise_result.dart              # Feature scores + overall percent

  services/
    api_service.dart                  # All HTTP calls to backend
    video_service.dart                # S3 video upload via presigned URL

  state/
    session_provider.dart             # ChangeNotifier with polling logic

  screens/
    home_screen.dart                  # Patient / Practitioner selector
    patient/
      session_start_screen.dart       # "Start Session" button
      questionnaire_screen.dart       # 10-question daily check-in (after assessment)
      device_link_screen.dart         # Enter device ID (server-side link, not BT)
      assess_waiting_screen.dart      # Poll for assessment results
      assessment_results_screen.dart  # 4x PASS/FAIL cards
      exercise_waiting_screen.dart    # Poll for exercise results
      exercise_results_screen.dart    # Scores + motivational message
    practitioner/
      session_list_screen.dart        # All sessions list
      session_detail_screen.dart      # Tabbed detail view

  widgets/
    result_card.dart                  # PASS/FAIL card
    score_bar.dart                    # Horizontal percentage bar
    video_player_widget.dart          # Network video player
```

## Dependencies

- `provider` — State management
- `http` — REST API calls
- `camera` — Optional video recording
- `video_player` — Video playback in practitioner view
- `intl` — Date formatting

## Running

```bash
cd flutter_app
flutter pub get
flutter run
```

## Detailed Docs

- `docs/conventions.md` — Coding patterns and rules
- `docs/flow.md` — Screen-by-screen flow + state machine
- `docs/api_contract.md` — Every endpoint with JSON shapes
