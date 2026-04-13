import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/session_provider.dart';
import '../../widgets/language_toggle.dart';
import 'exercise_results_screen.dart';

class ExerciseWaitingScreen extends StatefulWidget {
  const ExerciseWaitingScreen({super.key});

  @override
  State<ExerciseWaitingScreen> createState() => _ExerciseWaitingScreenState();
}

class _ExerciseWaitingScreenState extends State<ExerciseWaitingScreen> {
  bool _polling = false;
  bool _navigated = false;

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
    final exerciseName =
        neededTraining.isNotEmpty ? neededTraining.first : 'General';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage!)),
        );
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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.fitness_center, size: 64, color: Colors.teal),
            const SizedBox(height: 24),
            Text(
              t.exerciseLabel(exerciseName),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              t.exerciseDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
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
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              t.noGloveSimulate,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            provider.isSimulating
                ? const SizedBox(
                    height: 36,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : OutlinedButton.icon(
                    icon: const Icon(Icons.science_outlined),
                    label: Text(t.simulateGloveExercise),
                    onPressed: () {
                      context
                          .read<SessionProvider>()
                          .simulateGlove();
                      if (!_polling) _startPolling();
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
