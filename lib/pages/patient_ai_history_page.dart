import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:therapii/models/ai_conversation_summary.dart';
import 'package:therapii/pages/ai_summary_detail_page.dart';
import 'package:therapii/services/ai_conversation_service.dart';

class PatientAiHistoryPage extends StatefulWidget {
  const PatientAiHistoryPage({super.key});

  @override
  State<PatientAiHistoryPage> createState() => _PatientAiHistoryPageState();
}

class _PatientAiHistoryPageState extends State<PatientAiHistoryPage> {
  final _aiService = AiConversationService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = firebase_auth.FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Past Conversations')),
        body: const Center(child: Text('Please sign in to view your history.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Conversations'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<AiConversationSummary>>(
        stream: _aiService.streamPatientSummaries(patientId: user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'We could not load your conversation history right now.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
                ),
              ),
            );
          }

          final summaries = snapshot.data ?? const <AiConversationSummary>[];
          if (summaries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'You have not saved any AI conversations yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemBuilder: (context, index) {
              final summary = summaries[index];
              final date = summary.createdAt;
              final formatted =
                  '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year} '
                  '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
              final preview = summary.summary.length > 140
                  ? '${summary.summary.substring(0, 137)}…'
                  : summary.summary;

              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tileColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.psychology_alt_rounded, color: scheme.onPrimaryContainer),
                ),
                title: Text(
                  formatted,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AiSummaryDetailPage(summary: summary),
                    ),
                  );
                },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: summaries.length,
          );
        },
      ),
    );
  }
}
