import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/session_provider.dart';
import '../../widgets/language_toggle.dart';
import 'device_link_screen.dart';

class SessionStartScreen extends StatelessWidget {
  const SessionStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SessionProvider>();
    final t = AppLocalizations.of(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage!)),
        );
        provider.clearError();
      }
      if (provider.state == SessionState.linkingDevice) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DeviceLinkScreen()),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(t.startSession),
        actions: const [LanguageToggle()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.health_and_safety,
                  size: 80, color: Colors.teal),
              const SizedBox(height: 24),
              Text(
                t.readyToBegin,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                t.sessionIntro,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              provider.state == SessionState.creatingSession
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: Text(t.startNewSession),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () =>
                          context.read<SessionProvider>().startSession(),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
