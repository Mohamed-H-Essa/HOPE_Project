# HOPE Flutter App — Application Flow

## Session State Machine

```
idle → creatingSession → questionnaire → linkingDevice → waitingForAssessment → assessmentDone → waitingForExercise → exerciseDone
```

## Patient Flow (Step-by-Step)

1. **HomeScreen** → Tap "Patient" card
2. **SessionStartScreen** → Tap "Start New Session"
   - Creates session via `POST /sessions`
   - Navigates to QuestionnaireScreen
3. **QuestionnaireScreen** → Fill form, tap "Submit" or "Skip"
   - Submits via `PUT /sessions/{id}/questionnaire` (or skips)
   - Navigates to DeviceLinkScreen
4. **DeviceLinkScreen** → Enter device ID, tap "Link Device"
   - Links via `PUT /sessions/{id}/device`
   - Navigates to AssessWaitingScreen
5. **AssessWaitingScreen** → Shows spinner, polls every 3s
   - Polls `GET /sessions/{id}` until `assessment_results != null`
   - Auto-navigates to AssessmentResultsScreen (or shows timeout)
6. **AssessmentResultsScreen** → Shows 4 PASS/FAIL cards
   - Tap "Continue to Exercise"
   - Navigates to ExerciseWaitingScreen
7. **ExerciseWaitingScreen** → Shows exercise name, tap "Done"
   - Starts polling `GET /sessions/{id}` until `exercise_results != null`
   - Auto-navigates to ExerciseResultsScreen
8. **ExerciseResultsScreen** → Shows scores + message
   - Tap "Finish Session"
   - Returns to HomeScreen via `popUntil(isFirst)`

## Practitioner Flow

1. **HomeScreen** → Tap "Practitioner" card
2. **SessionListScreen** → Shows chronological list
   - Fetches via `GET /sessions`
   - Pull-to-refresh supported
   - Tap any item → SessionDetailScreen
3. **SessionDetailScreen** → 3 tabs (Assessment, Exercise, Info)
   - Fetches via `GET /sessions/{id}`
   - Shows video if available

## Polling Lifecycle

- **Start**: Called in `initState` or button tap
- **Check**: Every 3 seconds, max 20 ticks (60s timeout)
- **Success**: When data appears, cancel timer, navigate
- **Timeout**: Show SnackBar error, reset state
- **Cleanup**: Always cancel timer in `dispose()`

## Video Upload Flow

1. User records video (optional, in ExerciseWaitingScreen)
2. App requests presigned URL: `GET /sessions/{id}/video-upload-url`
3. App uploads bytes: `PUT <presigned_url>` with `Content-Type: video/mp4`
4. Re-upload overwrites same S3 key

## Cross-Session Persistence

- Sessions live in DynamoDB (managed by backend)
- App never stores sessions locally
- All session data fetched on demand via API
- Practitioner can view any past session
