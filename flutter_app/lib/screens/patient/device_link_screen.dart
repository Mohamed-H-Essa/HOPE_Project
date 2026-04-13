import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/session_provider.dart';
import '../../widgets/language_toggle.dart';
import 'assess_waiting_screen.dart';

class DeviceLinkScreen extends StatefulWidget {
  const DeviceLinkScreen({super.key});

  @override
  State<DeviceLinkScreen> createState() => _DeviceLinkScreenState();
}

class _DeviceLinkScreenState extends State<DeviceLinkScreen> {
  final _controller = TextEditingController(text: defaultDeviceId);
  bool _linking = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _linkDevice() async {
    setState(() => _linking = true);
    await context.read<SessionProvider>().linkDevice(_controller.text.trim());
    if (mounted) {
      setState(() => _linking = false);
      final error = context.read<SessionProvider>().errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        context.read<SessionProvider>().clearError();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AssessWaitingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.linkGloveDevice),
        actions: const [LanguageToggle()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.wifi, size: 64, color: Colors.teal),
            const SizedBox(height: 24),
            Text(
              t.linkGloveToSession,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              t.linkGloveDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: t.deviceId,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.wifi),
              ),
            ),
            const SizedBox(height: 24),
            _linking
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: const Icon(Icons.link),
                    label: Text(t.linkDevice),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _linkDevice,
                  ),
          ],
        ),
      ),
    );
  }
}
