import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../services/exercise_videos.dart';
import '../../state/session_provider.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/exercise_video_player.dart';
import '../../widgets/language_toggle.dart';
import '../../widgets/video_recorder_widget.dart';
import 'exercise_results_screen.dart';

class ExerciseWaitingScreen extends StatefulWidget {
  const ExerciseWaitingScreen({super.key});

  @override
  State<ExerciseWaitingScreen> createState() => _ExerciseWaitingScreenState();
}

class _ExerciseWaitingScreenState extends State<ExerciseWaitingScreen> {
  bool _polling = false;
  bool _navigated = false;
  // Local-only counter for the tutorial carousel. The backend always scores
  // needed_training[0] regardless of what the user is watching here — this
  // index just drives which YouTube video and label are shown.
  int _currentIndex = 0;

  void _startPolling() {
    setState(() => _polling = true);
    context.read<SessionProvider>().startPollingForExercise();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final t = AppLocalizations.of(context);
    final neededTraining =
        provider.currentSession?.assessmentResults?.neededTraining ?? [];
    final hasList = neededTraining.isNotEmpty;
    // Clamp in case the list shrinks underneath us (e.g. redo-assessment).
    final safeIndex = hasList ? _currentIndex.clamp(0, neededTraining.length - 1) : 0;
    final exerciseName = hasList ? neededTraining[safeIndex] : 'General';
    final isLast = !hasList || safeIndex >= neededTraining.length - 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.errorMessage != null) {
        showSessionError(context, provider.errorMessage);
        provider.clearError();
      }
      if (provider.state == SessionState.exerciseDone && !_navigated) {
        _navigated = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ExerciseResultsScreen()),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(t.exercise),
        actions: const [LanguageToggle()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.fitness_center, size: 64, color: Colors.teal),
            const SizedBox(height: 16),
            Text(
              hasList
                  ? t.exerciseProgress(
                      safeIndex + 1, neededTraining.length, exerciseName)
                  : t.exerciseLabel(exerciseName),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              t.exerciseDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ExerciseVideoPlayer(videoUrl: videoUrlFor(exerciseName)),
            if (hasList && !isLast) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  icon: const Icon(Icons.skip_next),
                  label: Text(t.nextExercise),
                  onPressed: () =>
                      setState(() => _currentIndex = safeIndex + 1),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const VideoRecorderWidget(),
            const SizedBox(height: 16),
            if (_polling) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Text(
                t.waitingForExercise,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ] else
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: Text(t.doneFetchResults),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _startPolling,
              ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              t.noGloveSimulate,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            provider.isSimulating
                ? const SizedBox(
                    height: 36,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : OutlinedButton.icon(
                    icon: const Icon(Icons.science_outlined),
                    label: Text(t.simulateGloveExercise),
                    onPressed: () {
                      context.read<SessionProvider>().simulateGlove();
                      if (!_polling) _startPolling();
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
