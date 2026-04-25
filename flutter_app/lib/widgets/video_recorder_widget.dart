import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../debug/app_logger.dart';
import '../l10n/gen/app_localizations.dart';
import '../state/session_provider.dart';

/// Inline video recorder for the exercise screen. Records at ~480p
/// (ResolutionPreset.medium) so uploads stay small and fast even on iPhones.
/// Stopping the recording uploads the file in the background.
class VideoRecorderWidget extends StatefulWidget {
  const VideoRecorderWidget({super.key});

  @override
  State<VideoRecorderWidget> createState() => _VideoRecorderWidgetState();
}

class _VideoRecorderWidgetState extends State<VideoRecorderWidget> {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _recording = false;
  bool _uploading = false;
  String? _lastResultKey;

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      // Prefer the front camera so the patient can see themselves.
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      // medium ≈ 480p — explicit per spec to keep upload fast on modern devices.
      final controller = CameraController(
        cam,
        ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e, st) {
      AppLogger.instance.logError('Camera init failed', e, st);
    }
  }

  Future<void> _start() async {
    final c = _controller;
    if (c == null || _recording) return;
    try {
      await c.startVideoRecording();
      setState(() {
        _recording = true;
        _lastResultKey = null;
      });
    } catch (e, st) {
      AppLogger.instance.logError('startVideoRecording failed', e, st);
    }
  }

  Future<void> _stopAndUpload() async {
    final c = _controller;
    if (c == null || !_recording) return;
    final provider = context.read<SessionProvider>();
    XFile file;
    try {
      file = await c.stopVideoRecording();
    } catch (e, st) {
      AppLogger.instance.logError('stopVideoRecording failed', e, st);
      setState(() => _recording = false);
      return;
    }
    setState(() {
      _recording = false;
      _uploading = true;
    });
    final ok = await provider.uploadSessionVideo(File(file.path));
    if (!mounted) return;
    setState(() {
      _uploading = false;
      _lastResultKey = ok ? 'uploaded' : 'failed';
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final c = _controller;
    return FutureBuilder(
      future: _initFuture,
      builder: (_, snap) {
        if (c == null || !c.value.isInitialized) {
          return const SizedBox(
            height: 80,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: CameraPreview(c),
            ),
            const SizedBox(height: 8),
            if (_uploading)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(t.uploadingVideo),
                ],
              )
            else if (_recording)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
                icon: const Icon(Icons.stop),
                label: Text(t.stopRecording),
                onPressed: _stopAndUpload,
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.videocam),
                label: Text(t.recordVideo),
                onPressed: _start,
              ),
            if (_lastResultKey != null) ...[
              const SizedBox(height: 4),
              Text(
                _lastResultKey == 'uploaded'
                    ? t.videoUploaded
                    : t.videoUploadFailed,
                style: TextStyle(
                  color: _lastResultKey == 'uploaded'
                      ? Colors.green
                      : Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }
}
