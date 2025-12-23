import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:therapii/models/ai_conversation_summary.dart';
import 'package:therapii/services/user_service.dart';

class AdminAiChatsPage extends StatefulWidget {
  const AdminAiChatsPage({super.key});

  @override
  State<AdminAiChatsPage> createState() => _AdminAiChatsPageState();
}

class _AdminAiChatsPageState extends State<AdminAiChatsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserService _userService = UserService();
  final Map<String, String> _nameCache = {};

  Future<String> _resolveName(String id) async {
    if (id.isEmpty) return 'Unknown';
    if (_nameCache.containsKey(id)) return _nameCache[id]!;
    try {
      final user = await _userService.getUser(id);
      final name = (user?.fullName ?? user?.email ?? '').trim();
      final resolved = name.isEmpty ? id : name;
      _nameCache[id] = resolved;
      return resolved;
    } catch (_) {
      return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Chats'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('ai_conversation_summaries')
            .orderBy('created_at', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load AI chats', style: theme.textTheme.bodyLarge));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final summaries = snapshot.data!.docs.map(AiConversationSummary.fromDoc).toList();
          if (summaries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No AI chats recorded yet', style: theme.textTheme.titleMedium),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: summaries.length,
            itemBuilder: (context, index) {
              final summary = summaries[index];
              return FutureBuilder<List<String>>(
                future: Future.wait([_resolveName(summary.therapistId), _resolveName(summary.patientId)]),
                builder: (context, snapshot) {
                  final therapistName = snapshot.data != null ? snapshot.data![0] : summary.therapistId;
                  final patientName = snapshot.data != null ? snapshot.data![1] : summary.patientId;
                  return _AiChatCard(
                    therapistName: therapistName,
                    patientName: patientName,
                    summary: summary.summary,
                    createdAt: summary.createdAt,
                    scheme: scheme,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _AiChatCard extends StatelessWidget {
  final String therapistName;
  final String patientName;
  final String summary;
  final DateTime createdAt;
  final ColorScheme scheme;

  const _AiChatCard({
    required this.therapistName,
    required this.patientName,
    required this.summary,
    required this.createdAt,
    required this.scheme,
  });

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Therapist: $therapistName',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Patient: $patientName', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 8),
          Text('Created: ${_formatDate(createdAt)}', style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
