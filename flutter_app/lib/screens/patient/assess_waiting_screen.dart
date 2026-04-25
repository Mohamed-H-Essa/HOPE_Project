import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/session_provider.dart';
import '../../widgets/error_snackbar.dart';
import '../../widgets/language_toggle.dart';
import 'assessment_results_screen.dart';

class AssessWaitingScreen extends StatefulWidget {
  const AssessWaitingScreen({super.key});

  @override
  State<AssessWaitingScreen> createState() => _AssessWaitingScreenState();
}

class _AssessWaitingScreenState extends State<AssessWaitingScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SessionProvider>().startPollingForAssessment();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final t = AppLocalizations.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.errorMessage != null) {
        showSessionError(context, provider.errorMessage);
        provider.clearError();
      }
      if (provider.state == SessionState.assessmentDone && !_navigated) {
        _navigated = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AssessmentResultsScreen()),
        );
      }
    });

    final simulating = provider.isSimulating;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.assessment),
        actions: const [LanguageToggle()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 32),
              Text(
                t.waitingForAssessment,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                t.assessmentDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                t.noGloveSimulate,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 8),
              simulating
                  ? const SizedBox(
                      height: 36,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : OutlinedButton.icon(
                      icon: const Icon(Icons.science_outlined),
                      label: Text(t.simulateGloveAssessment),
                      onPressed: () => context
                          .read<SessionProvider>()
                          .simulateGlove(),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
