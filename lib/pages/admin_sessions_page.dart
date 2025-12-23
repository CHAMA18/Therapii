import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:therapii/models/chat_conversation.dart';
import 'package:therapii/services/user_service.dart';

class AdminSessionsPage extends StatefulWidget {
  const AdminSessionsPage({super.key});

  @override
  State<AdminSessionsPage> createState() => _AdminSessionsPageState();
}

class _AdminSessionsPageState extends State<AdminSessionsPage> {
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Sessions'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('conversations')
            .orderBy('updated_at', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load sessions', style: theme.textTheme.bodyLarge));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final conversations = snapshot.data!.docs.map(ChatConversation.fromDoc).toList();
          if (conversations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No sessions yet', style: theme.textTheme.titleMedium),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final convo = conversations[index];
              return FutureBuilder<List<String>>(
                future: Future.wait([_resolveName(convo.therapistId), _resolveName(convo.patientId)]),
                builder: (context, snapshot) {
                  final therapistName = snapshot.data != null ? snapshot.data![0] : convo.therapistId;
                  final patientName = snapshot.data != null ? snapshot.data![1] : convo.patientId;
                  return _SessionCard(
                    therapistName: therapistName,
                    patientName: patientName,
                    lastMessage: convo.lastMessageText ?? 'No messages yet',
                    lastMessageAt: _formatDate(convo.lastMessageAt ?? convo.updatedAt),
                    therapistUnread: convo.therapistUnreadCount,
                    patientUnread: convo.patientUnreadCount,
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

class _SessionCard extends StatelessWidget {
  final String therapistName;
  final String patientName;
  final String lastMessage;
  final String lastMessageAt;
  final int therapistUnread;
  final int patientUnread;
  final ColorScheme scheme;

  const _SessionCard({
    required this.therapistName,
    required this.patientName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.therapistUnread,
    required this.patientUnread,
    required this.scheme,
  });

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
              Icon(Icons.forum_outlined, color: scheme.primary),
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
            lastMessage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 8),
          Wrap(
            runSpacing: 8,
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('Last activity: $lastMessageAt', style: Theme.of(context).textTheme.labelMedium),
              ),
              _pill('T unread: $therapistUnread', scheme.primary.withValues(alpha: 0.12), scheme.primary),
              _pill('P unread: $patientUnread', scheme.secondary.withValues(alpha: 0.12), scheme.secondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      );
}
