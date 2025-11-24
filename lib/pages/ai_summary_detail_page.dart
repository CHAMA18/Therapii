import 'package:flutter/material.dart';
import 'package:therapii/models/ai_conversation_summary.dart';
import 'package:therapii/services/user_service.dart';
import 'package:therapii/models/user.dart' as app_user;

class AiSummaryDetailPage extends StatefulWidget {
  final AiConversationSummary summary;
  const AiSummaryDetailPage({super.key, required this.summary});

  @override
  State<AiSummaryDetailPage> createState() => _AiSummaryDetailPageState();
}

class _AiSummaryDetailPageState extends State<AiSummaryDetailPage> {
  final _userService = UserService();
  app_user.User? _patient;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final u = await _userService.getUser(widget.summary.patientId);
      if (!mounted) return;
      setState(() {
        _patient = u;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.summary;
    final title = _patient?.fullName.isNotEmpty == true ? _patient!.fullName : 'Patient summary';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(_formatDate(s.createdAt), style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'AI Conversation Summary',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.summary,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                  if (s.transcript.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Transcript', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final m in s.transcript) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                '${_label(m.role)}: ${m.text}',
                                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  String _formatDate(DateTime date) {
    final months = const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _label(String role) {
    switch (role) {
      case 'user':
        return 'Patient';
      case 'assistant':
        return 'AI';
      default:
        return role;
    }
  }
}
