import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/session.dart';
import '../services/api_service.dart';
import '../services/video_service.dart';
import '../debug/app_logger.dart';
import '../debug/debug_log_entry.dart';
import '../debug/debug_log_store.dart';
import '../debug/logging_http_client.dart';

enum SessionState {
  idle,
  creatingSession,
  linkingDevice,
  waitingForAssessment,
  assessmentDone,
  questionnaire,
  waitingForExercise,
  exerciseDone,
}

class SessionProvider extends ChangeNotifier {
  late final ApiService _api;
  late final VideoService _video;
  final DebugLogStore logStore;

  SessionState _state = SessionState.idle;
  Session? _currentSession;
  String? _errorMessage;
  Timer? _pollingTimer;
  int _pollCount = 0;

  static const int _maxPolls = 60; // 3 minutes at 3s intervals
  static const Duration _pollInterval = Duration(seconds: 3);

  SessionProvider({DebugLogStore? logStore})
      : logStore = logStore ?? DebugLogStore() {
    final client = LoggingHttpClient(store: this.logStore);
    _api = ApiService(client);
    _video = VideoService(client);
  }

  SessionState get state => _state;
  Session? get currentSession => _currentSession;
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  void _setState(SessionState newState) {
    if (_state == newState) return;
    final prev = _state.name;
    _state = newState;
    AppLogger.instance.logStateChange(prev, newState.name);
    logStore.addStateChange(StateChangeEvent(
      from: prev,
      to: newState.name,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  Future<void> startSession() async {
    _setState(SessionState.creatingSession);
    try {
      final sessionId = await _api.createSession();
      _currentSession = await _api.getSession(sessionId);
      _setState(SessionState.linkingDevice);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _setState(SessionState.idle);
    } catch (e) {
      _errorMessage = 'Failed to create session';
      _setState(SessionState.idle);
    }
  }

  Future<void> submitQuestionnaire(Map<String, dynamic> answers) async {
    if (_currentSession == null) return;
    try {
      await _api.submitQuestionnaire(_currentSession!.sessionId, answers);
      _setState(SessionState.waitingForExercise);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to submit questionnaire';
      notifyListeners();
    }
  }

  void skipQuestionnaire() {
    _setState(SessionState.waitingForExercise);
  }

  Future<void> linkDevice(String deviceId) async {
    if (_currentSession == null) return;
    try {
      await _api.linkDevice(_currentSession!.sessionId, deviceId);
      _currentSession = await _api.getSession(_currentSession!.sessionId);
      _setState(SessionState.waitingForAssessment);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to link device';
      notifyListeners();
    }
  }

  void startPollingForAssessment() {
    if (_currentSession == null) return;
    _pollCount = 0;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollInterval, (_) => _pollAssessment());
  }

  Future<void> _pollAssessment() async {
    if (_currentSession == null) {
      _pollingTimer?.cancel();
      return;
    }
    _pollCount++;
    if (_pollCount > _maxPolls) {
      _pollingTimer?.cancel();
      _errorMessage = 'Assessment timed out. Please try again.';
      _setState(SessionState.idle);
      return;
    }
    try {
      final session = await _api.getSession(_currentSession!.sessionId);
      _currentSession = session;
      if (session.assessmentResults != null) {
        _pollingTimer?.cancel();
        _setState(SessionState.assessmentDone);
      }
    } on ApiException catch (e) {
      AppLogger.instance.logError('Poll assessment error', e);
    }
  }

  void startPollingForExercise() {
    if (_currentSession == null) return;
    _pollCount = 0;
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollInterval, (_) => _pollExercise());
  }

  Future<void> _pollExercise() async {
    if (_currentSession == null) {
      _pollingTimer?.cancel();
      return;
    }
    _pollCount++;
    if (_pollCount > _maxPolls) {
      _pollingTimer?.cancel();
      _errorMessage = 'Exercise timed out. Please try again.';
      _setState(SessionState.assessmentDone);
      return;
    }
    try {
      final session = await _api.getSession(_currentSession!.sessionId);
      _currentSession = session;
      if (session.exerciseResults != null) {
        _pollingTimer?.cancel();
        _setState(SessionState.exerciseDone);
      }
    } on ApiException catch (e) {
      AppLogger.instance.logError('Poll exercise error', e);
    }
  }

  Future<void> uploadSessionVideo(File videoFile) async {
    if (_currentSession == null) return;
    try {
      final uploadUrl = await _api.getVideoUploadUrl(_currentSession!.sessionId);
      await _video.uploadVideoWithUrl(uploadUrl, videoFile);
      AppLogger.instance.logInfo('Video uploaded successfully');
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to upload video';
      notifyListeners();
    }
  }

  // --- Simulator ---

  bool _simulating = false;
  bool get isSimulating => _simulating;

  Future<void> simulateGlove() async {
    if (_currentSession == null) return;
    final deviceId = _currentSession!.deviceId;
    if (deviceId == null) return;

    _simulating = true;
    notifyListeners();
    try {
      await _api.simulateGlove(deviceId);
      AppLogger.instance.logInfo('Glove simulated for device $deviceId');
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Simulation failed';
    } finally {
      _simulating = false;
      notifyListeners();
    }
  }

  // --- Practitioner ---

  List<SessionSummary> _sessionHistory = [];
  List<SessionSummary> get sessionHistory => List.unmodifiable(_sessionHistory);

  Future<void> loadSessionHistory() async {
    try {
      _sessionHistory = await _api.listSessions();
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load sessions';
      notifyListeners();
    }
  }

  Future<Session?> loadSessionDetail(String sessionId) async {
    try {
      return await _api.getSession(sessionId);
    } on ApiException {
      return null;
    } catch (e) {
      return null;
    }
  }

  void resetSession() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _pollCount = 0;
    _currentSession = null;
    _errorMessage = null;
    _setState(SessionState.idle);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
