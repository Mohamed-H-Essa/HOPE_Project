import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/session.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => 'ApiException: $message';
}

class ApiService {
  final http.Client _client;

  ApiService(this._client);

  Future<String> createSession() async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/sessions'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw ApiException('Failed to create session: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['session_id'] as String;
  }

  Future<void> submitQuestionnaire(
    String sessionId,
    Map<String, dynamic> answers,
  ) async {
    final response = await _client.put(
      Uri.parse('$apiBaseUrl/sessions/$sessionId/questionnaire'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(answers),
    );
    if (response.statusCode != 200) {
      throw ApiException(
          'Failed to submit questionnaire: ${response.statusCode}');
    }
  }

  Future<void> linkDevice(String sessionId, String deviceId) async {
    final response = await _client.put(
      Uri.parse('$apiBaseUrl/sessions/$sessionId/device'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'device_id': deviceId}),
    );
    if (response.statusCode != 200) {
      throw ApiException('Failed to link device: ${response.statusCode}');
    }
  }

  Future<Session> getSession(String sessionId) async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/sessions/$sessionId'),
    );
    if (response.statusCode != 200) {
      throw ApiException('Failed to get session: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Session.fromJson(data);
  }

  Future<List<SessionSummary>> listSessions() async {
    final response = await _client.get(
      Uri.parse('$apiBaseUrl/sessions'),
    );
    if (response.statusCode != 200) {
      throw ApiException('Failed to list sessions: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['sessions'] as List<dynamic>;
    return items
        .map((e) => SessionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Simulate the glove by sending a batch of sensor data to /ingest.
  /// Matches the exact format the ESP32 firmware sends: 100 samples at 50ms
  /// intervals with realistic sensor ranges. The backend auto-detects whether
  /// to run assessment or exercise logic from the session's status — the glove
  /// (and this simulation) never need to specify a phase.
  Future<void> simulateGlove(String deviceId) async {
    final rng = Random();
    final samples = List.generate(100, (i) => {
      // 50ms intervals matching firmware's delay(50) between samples
      'time': i * 50,
      // flex sensors: 0-90° range (finger bend angle)
      'flex1': (30 + 30 * (0.5 + 0.5 * (i % 20) / 20) + rng.nextDouble() * 10 - 5).round(),
      'flex2': (35 + 25 * (0.5 + 0.5 * (i % 25) / 25) + rng.nextDouble() * 10 - 5).round(),
      // FSR sensors: 0-100 force percentage
      'fsr1': (20 + 40 * (0.8 + rng.nextDouble() * 0.4)).round().clamp(0, 100),
      'fsr2': (15 + 35 * (0.8 + rng.nextDouble() * 0.4)).round().clamp(0, 100),
      // EMG: ~300 baseline with variation (matches firmware range)
      'emg': (250 + rng.nextDouble() * 100).round(),
      // Accelerometer: raw MPU6050 int16 LSB, default FS_SEL=0 → ±2g (16384 LSB/g);
      // az ≈ 16384 at rest (1g gravity on z-axis).
      'ax': (rng.nextDouble() * 2000 - 1000).round(),
      'ay': (rng.nextDouble() * 1000 - 500).round(),
      'az': (16000 + rng.nextDouble() * 1000 - 500).round(),
      // Gyroscope: raw MPU6050 int16 LSB, default FS_SEL=0 → ±250°/s (131 LSB/(°/s)).
      // See firmware/FIRMWARE.md#sensors for the canonical schema.
      'gx': (rng.nextDouble() * 200 - 100).round(),
      'gy': (rng.nextDouble() * 160 - 80).round(),
      'gz': (rng.nextDouble() * 240 - 120).round(),
    });

    final body = jsonEncode({
      'device_id': deviceId,
      'data': samples,
    });

    http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$apiBaseUrl/ingest'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    } on Exception {
      // Retry once — Lambda cold-starts can cause the connection to be dropped
      // before the response headers arrive (CloudFront idle timeout ~15s).
      response = await _client.post(
        Uri.parse('$apiBaseUrl/ingest'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw ApiException('Simulate glove failed: ${response.statusCode}');
    }
  }

  Future<String> getVideoUploadUrl(String sessionId) async {
    final response = await _client.post(
      Uri.parse('$apiBaseUrl/sessions/$sessionId/video-upload-url'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiException('Failed to get upload URL: ${response.statusCode}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['upload_url'] as String;
  }
}
