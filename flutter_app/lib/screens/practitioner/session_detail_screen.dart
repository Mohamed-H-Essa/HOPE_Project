import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/session.dart';
import '../../state/session_provider.dart';
import '../../widgets/language_toggle.dart';
import '../../widgets/result_card.dart';
import '../../widgets/score_bar.dart';
import '../../widgets/video_player_widget.dart';

class SessionDetailScreen extends StatelessWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.sessionDetail),
        actions: const [LanguageToggle()],
      ),
      body: FutureBuilder<Session?>(
        future: context.read<SessionProvider>().loadSessionDetail(sessionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final session = snapshot.data;
          if (session == null) {
            return Center(child: Text(t.failedToLoadSession));
          }
          return DefaultTabController(
            length: 3,
            child: Column(
              children: [
                TabBar(
                  tabs: [
                    Tab(text: t.tabAssessment),
                    Tab(text: t.tabExercise),
                    Tab(text: t.tabInfo),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _AssessmentTab(session: session),
                      _ExerciseTab(session: session),
                      _InfoTab(session: session),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AssessmentTab extends StatelessWidget {
  final Session session;
  const _AssessmentTab({required this.session});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final results = session.assessmentResults;
    if (results == null) {
      return Center(child: Text(t.noAssessmentData));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: results.functionResults.entries
          .map((e) => ResultCard(
                functionName: e.key,
                passed: e.value == 'PASS',
              ))
          .toList(),
    );
  }
}

class _ExerciseTab extends StatelessWidget {
  final Session session;
  const _ExerciseTab({required this.session});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final exercise = session.exerciseResults;
    if (exercise == null) {
      return Center(child: Text(t.noExerciseData));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          exercise.exercise,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          t.overallPercent(exercise.overallPercent.toStringAsFixed(1)),
          style: const TextStyle(fontSize: 18, color: Colors.teal),
        ),
        const SizedBox(height: 4),
        Text(exercise.message),
        const SizedBox(height: 16),
        ...exercise.features.entries.map(
          (e) => ScoreBar(label: e.key, percent: e.value),
        ),
      ],
    );
  }
}

class _InfoTab extends StatelessWidget {
  final Session session;
  const _InfoTab({required this.session});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final q = session.questionnaire;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (q != null) ...[
          Text(
            t.questionnaire,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...q.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      e.key,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Expanded(child: Text(e.value.toString())),
                ],
              ),
            ),
          ),
          const Divider(height: 32),
        ],
        if (session.videoUrl != null) ...[
          Text(
            t.sessionVideo,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          VideoPlayerWidget(videoUrl: session.videoUrl!),
        ],
      ],
    );
  }
}
