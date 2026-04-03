# HOPE — Flutter App

Root: `flutter_app/`

## Folder Structure

```
flutter_app/
  lib/
    main.dart                          # App entry: runApp, MaterialApp, Provider, routes
    config.dart                        # API base URL constant

    models/
      session.dart                     # Full session model
      assessment_result.dart           # PASS/FAIL per function + needed_training
      exercise_result.dart             # Feature scores, overall_percent, message

    services/
      api_service.dart                 # All HTTP calls (see api.md)
      video_service.dart               # Camera recording + S3 presigned upload

    state/
      session_provider.dart            # ChangeNotifier: current session + polling

    screens/
      home_screen.dart                 # Patient / Practitioner mode selector

      patient/
        session_start_screen.dart      # Step 1 — "Start Session"
        questionnaire_screen.dart      # Step 2 — Placeholder questions
        assess_waiting_screen.dart     # Step 3 — Waiting for assessment results
        assessment_results_screen.dart # Step 4 — PASS/FAIL display
        exercise_screen.dart           # Step 5 — Exercise + optional video
        exercise_results_screen.dart   # Step 6 — Scores + message

      practitioner/
        session_list_screen.dart       # All past sessions list
        session_detail_screen.dart     # Full session detail + video playback

    widgets/
      result_card.dart                 # Reusable PASS/FAIL card
      score_bar.dart                   # Horizontal percentage bar
      video_player_widget.dart         # Wraps video_player package
```

---

## pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  provider: ^6.1.2
  http: ^1.2.2
  camera: ^0.11.0
  video_player: ^2.9.2
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

---

## config.dart

```dart
class AppConfig {
  static const String apiBaseUrl =
      'https://<api-gateway-id>.execute-api.us-east-1.amazonaws.com/prod';
}
```

---

## Models

### session.dart

```dart
class Session {
  final String sessionId;
  final String createdAt;
  final String status;
  final Map<String, dynamic>? questionnaire;
  final AssessmentResult? assessmentResults;
  final ExerciseResult? exerciseResults;
  final String? videoUrl;

  Session.fromJson(Map<String, dynamic> json) : ...
}
```

### assessment_result.dart

```dart
class AssessmentResult {
  final Map<String, bool> results;   // {"Reach": true, "Grasp": false, ...}
  final List<String> neededTraining; // ["Grasp", "Release"]
  final Map<String, double> features; // computed feature values

  AssessmentResult.fromJson(Map<String, dynamic> json) : ...

  bool get isPassed => neededTraining.isEmpty;
}
```

### exercise_result.dart

```dart
class ExerciseResult {
  final String exercise;
  final Map<String, double> features;
  final double overallPercent;
  final String message;
  final String timestamp;

  ExerciseResult.fromJson(Map<String, dynamic> json) : ...
}
```

---

## ApiService

All 6 Flutter-facing HTTP calls in one class. The assess and exercise endpoints are called by the ESP32.

```dart
class ApiService {
  final String _base = AppConfig.apiBaseUrl;
  final http.Client _client = http.Client();

  // Creates a new session, returns session_id string
  Future<String> createSession()

  // Saves questionnaire answers
  Future<void> saveQuestionnaire(String sessionId, Map<String, dynamic> answers)

  // Returns presigned S3 PUT URL for video upload
  Future<String> getVideoUploadUrl(String sessionId)

  // Uploads raw video bytes to S3 presigned URL
  Future<void> uploadVideo(String presignedUrl, File videoFile)

  // Returns list of sessions (for practitioner list screen)
  Future<List<Session>> listSessions()

  // Returns full session detail (used for polling + practitioner detail)
  Future<Session> getSession(String sessionId)
}
```

All methods throw an `ApiException` on non-2xx status codes. The provider catches these and sets `errorMessage`.

---

## VideoService

```dart
class VideoService {
  // Initialize camera controller
  Future<CameraController> initCamera()

  // Start recording
  Future<void> startRecording(CameraController controller)

  // Stop recording, return path to local file
  Future<File> stopRecording(CameraController controller)

  // Upload local file to S3 using presigned URL
  Future<void> uploadToS3(String presignedUrl, File file)
}
```

---

## State Management

### SessionProvider (ChangeNotifier)

```dart
enum SessionStatus { idle, questionnaire, assessing, assessmentDone, exercising, exerciseDone }

class SessionProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  String? currentSessionId;
  SessionStatus status = SessionStatus.idle;
  Session? currentSession;
  List<Session> sessionHistory = [];
  bool isLoading = false;
  String? errorMessage;
  Timer? _pollTimer;

  // Step 1
  Future<void> startSession() async { ... }

  // Step 2
  Future<void> submitQuestionnaire(Map<String, dynamic> answers) async { ... }

  // Step 3: Polls GET /sessions/{id} every 3s, stops when assessment_results present
  void startPollingForAssessment() { ... }

  // Step 5: Polls for exercise_results
  void startPollingForExercise() { ... }

  void stopPolling() { _pollTimer?.cancel(); }

  // Step 5: Video upload flow
  Future<void> uploadSessionVideo(File videoFile) async { ... }

  // Practitioner
  Future<void> loadSessionHistory() async { ... }
  Future<Session> loadSessionDetail(String id) async { ... }
}
```

**Polling logic:**
```dart
void startPollingForAssessment() {
  _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
    if (timer.tick > 20) { // 60s timeout
      timer.cancel();
      errorMessage = 'Timed out waiting for assessment. Is the glove connected?';
      notifyListeners();
      return;
    }
    final session = await _api.getSession(currentSessionId!);
    if (session.assessmentResults != null) {
      timer.cancel();
      currentSession = session;
      status = SessionStatus.assessmentDone;
      notifyListeners();
    }
  });
}
```

---

## Screens Detail

### home_screen.dart

Two large cards centered vertically:
- **Patient** — teal icon, navigates to `session_start_screen.dart`
- **Practitioner** — indigo icon, navigates to `session_list_screen.dart`

---

### patient/session_start_screen.dart

- Title: "HOPE"
- Subtitle: "Rehabilitation Session"
- Large teal "Start Session" `ElevatedButton`
- On tap: calls `provider.startSession()`, shows `CircularProgressIndicator`, then pushes questionnaire screen on success

---

### patient/questionnaire_screen.dart

Hardcoded placeholder questions — can be updated later:

| # | Question | Widget |
|---|----------|--------|
| 1 | Pain level today (1–10) | `Slider` |
| 2 | Experiencing stiffness? | `Switch` |
| 3 | Any comments | `TextFormField` |

Two buttons: **Skip** (navigates forward without API call) and **Submit** (calls `provider.submitQuestionnaire()`, then navigates).

---

### patient/assess_waiting_screen.dart

- Header: "Assessment"
- Large icon (e.g. hand/glove icon)
- Text: "Put on the glove and flex your hand"
- Animated `CircularProgressIndicator`
- Starts polling on `initState` via `provider.startPollingForAssessment()`
- When `provider.status == SessionStatus.assessmentDone`, auto-pushes to results screen
- Shows timeout error in a `SnackBar`

---

### patient/assessment_results_screen.dart

- Header: "Assessment Results"
- Four `ResultCard` widgets in a `ListView`:
  - Reach ✓/✗
  - Grasp ✓/✗
  - Manipulation ✓/✗
  - Release ✓/✗
- If all PASS: "No exercises needed!" message
- If any FAIL: "Functions needing training: ..." list
- "Continue to Exercises" `ElevatedButton`

---

### patient/exercise_screen.dart

- Header: "Exercise Session"
- Shows which exercises to do (from `neededTraining` list)
- Instruction text
- "Record Video (Optional)" `OutlinedButton` — opens camera, records, shows thumbnail when done
- Large "Done — Submit Exercise" `ElevatedButton`
  - If video: calls `provider.uploadSessionVideo(file)` first
  - Then calls `provider.startPollingForExercise()`
  - Shows loading overlay during upload and polling
- Same polling auto-navigate pattern as assess waiting screen

---

### patient/exercise_results_screen.dart

- Header: "Exercise Results"
- Exercise name + date
- Per-feature `ScoreBar` widgets (e.g., "Force: 72%", "Flex: 68%")
- Large overall score circle (big `Text` with percent)
- Motivational message in a `Card`
- "Finish Session" button → pops to home

---

### practitioner/session_list_screen.dart

- `AppBar` with "Practitioner Dashboard"
- `ListView.builder` from `provider.sessionHistory`
- Each `ListTile`:
  - Date (formatted from `created_at`)
  - Status chip
  - Quick summary: "2/4 PASS | Exercise: 70%"
- Pull-to-refresh calls `provider.loadSessionHistory()`
- Tap navigates to `session_detail_screen.dart`

---

### practitioner/session_detail_screen.dart

Scrollable single screen (or `DefaultTabController` with 3 tabs):

**Tab 1 — Assessment:**
- Same PASS/FAIL cards as patient results screen (read-only display)

**Tab 2 — Exercise:**
- Same score bars as patient exercise results (read-only display)

**Tab 3 — Info:**
- Questionnaire answers (`ListView` of key-value pairs)
- Session date/time
- Video player if `session.videoUrl != null` (uses `VideoPlayerWidget`)

---

## Widgets

### result_card.dart

```dart
class ResultCard extends StatelessWidget {
  final String functionName; // "Reach", "Grasp", etc.
  final bool passed;         // true = PASS, false = FAIL
  // ...
}
```

Displays a `Card` with:
- Function name
- Green checkmark icon (PASS) or red X icon (FAIL)
- "PASS" / "FAIL" text in matching color

---

### score_bar.dart

```dart
class ScoreBar extends StatelessWidget {
  final String label;    // "Force"
  final double score;    // 0–100
  // ...
}
```

A `Row` with label, `LinearProgressIndicator`, and percentage text.
Color: green if >70, amber if 50–70, red if <50.

---

### video_player_widget.dart

```dart
class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl; // presigned S3 URL
  // ...
}
```

Wraps `VideoPlayerController.networkUrl(Uri.parse(videoUrl))`, shows play/pause controls and a seek bar.

---

## Theme

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0A9396), // teal — healthcare feel
    brightness: Brightness.light,
  ),
)
```

---

## Navigation

Simple `Navigator.push` / `Navigator.pop` — no named routes needed for a linear demo flow. The patient flow is a stack; "Finish Session" pops all the way back to home using `Navigator.popUntil`.
