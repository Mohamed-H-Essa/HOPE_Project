# HOPE Flutter App — Application Flow

## How the System Works (Read This First)

The app and the glove do NOT communicate directly. There is no Bluetooth.

```
App (phone)  ──REST API──►  Backend (AWS)  ◄──WiFi HTTP──  Glove (ESP32)
```

1. App creates a session and links a device_id to it
2. Glove sends sensor data to `/ingest` with its device_id
3. Backend matches device_id → session, processes data, writes results
4. App polls GET /sessions/{id} until results appear

## Session State Machine (Provider)

```
idle → creatingSession → questionnaire → linkingDevice → waitingForAssessment → assessmentDone → waitingForExercise → exerciseDone
```

This is the Flutter `SessionState` enum in `session_provider.dart`. It tracks
the app's UI state, not the backend status.

## Backend Session Status (DynamoDB)

```
created → questionnaire_done → assessed → exercised
```

The app polls the backend and checks for the presence of `assessment_results`
or `exercise_results` fields, not the status string directly.

## Patient Flow (Step-by-Step)

1. **HomeScreen** → Tap "Patient" card
2. **SessionStartScreen** → Tap "Start New Session"
   - Creates session via `POST /sessions`
   - Navigates to QuestionnaireScreen
3. **QuestionnaireScreen** → Fill form, tap "Submit" or "Skip"
   - Submits via `PUT /sessions/{id}/questionnaire` (or skips)
   - Navigates to DeviceLinkScreen
4. **DeviceLinkScreen** → Enter device ID (default: `hope-glove-01`), tap "Link"
   - Links via `PUT /sessions/{id}/device`
   - This tells the backend which session to route the glove's data to
   - **No Bluetooth pairing happens here** — just a server-side string association
   - Navigates to AssessWaitingScreen
5. **AssessWaitingScreen** → Shows spinner, polls every 3s
   - Meanwhile, the patient wears the glove and performs assessment motions
   - Glove sends sensor data over WiFi to `/ingest`
   - Backend processes data and writes `assessment_results` to DynamoDB
   - App detects `assessment_results != null` on next poll
   - Auto-navigates to AssessmentResultsScreen (or shows timeout after 60s)
6. **AssessmentResultsScreen** → Shows 4 PASS/FAIL cards (Reach, Grasp, Manipulation, Release)
   - Tap "Continue to Exercise"
   - Navigates to ExerciseWaitingScreen
7. **ExerciseWaitingScreen** → Shows which exercise to perform
   - Patient performs exercise with glove
   - Tap "Done — Fetch Results" starts polling
   - Glove sends more sensor data → backend runs exercise logic
   - App detects `exercise_results != null`
   - Auto-navigates to ExerciseResultsScreen
8. **ExerciseResultsScreen** → Shows per-feature scores + motivational message
   - Tap "Finish Session" → returns to HomeScreen

## Practitioner Flow

1. **HomeScreen** → Tap "Practitioner" card
2. **SessionListScreen** → Shows all sessions chronologically
   - Fetches via `GET /sessions`
   - Pull-to-refresh supported
   - Each item shows date, status chip, assessment/exercise summary
   - Tap any item → SessionDetailScreen
3. **SessionDetailScreen** → 3 tabs
   - **Assessment**: PASS/FAIL cards for each function
   - **Exercise**: Score bars per feature + overall + motivational message
   - **Info**: Questionnaire answers + video player (if video exists)

## Polling Lifecycle

```
Start polling (Timer.periodic, 3s interval)
  ├── Poll 1..20: GET /sessions/{id}, check for results
  │   ├── Results found → cancel timer, navigate to results screen
  │   └── Not yet → continue polling
  └── Poll 21: Timeout → cancel timer, show error SnackBar, reset state
```

Always cancel timer in `dispose()` to prevent leaks.

## Video Upload Flow

1. Patient records video (optional, during exercise)
2. App calls `POST /sessions/{id}/video-upload-url` → gets presigned S3 PUT URL
3. App uploads raw bytes: `PUT <presigned_url>` with `Content-Type: video/mp4`
4. Re-upload overwrites the same S3 key
5. Practitioner views video via presigned GET URL in session detail

## Cross-Session Persistence

- Sessions live in DynamoDB — the app stores nothing locally
- All session data is fetched on demand via the API
- Practitioner can view any past session at any time
