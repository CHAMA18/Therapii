import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:therapii/models/ai_conversation_summary.dart';
import 'package:therapii/services/ai_conversation_service.dart';
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
  final _aiConversationService = AiConversationService();
  app_user.User? _patient;
  bool _loading = true;
  bool _isTherapist = false;
  late AiConversationSummary _summary;

  @override
  void initState() {
    super.initState();
    _summary = widget.summary;
    _load();
  }

  Future<void> _load() async {
    try {
      final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
      final u = await _userService.getUser(widget.summary.patientId);
      if (!mounted) return;
      setState(() {
        _patient = u;
        _isTherapist = currentUser?.uid == widget.summary.therapistId;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _showFeedbackDialog() async {
    final controller = TextEditingController(text: _summary.therapistFeedback ?? '');
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.rate_review_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _summary.therapistFeedback != null ? 'Edit Feedback' : 'Add Feedback',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Provide feedback on this AI conversation to help improve the model\'s responses for this patient.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter your feedback here...',
                  filled: true,
                  fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Feedback'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        await _aiConversationService.saveTherapistFeedback(
          summaryId: _summary.id,
          feedback: result,
        );
        if (!mounted) return;
        setState(() {
          _summary = _summary.copyWith(
            therapistFeedback: result,
            feedbackUpdatedAt: DateTime.now(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback saved successfully')),
        );
      } catch (e) {
        debugPrint('[AiSummaryDetailPage] Error saving feedback: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save feedback: $e')),
        );
      }
    }
  }

  Widget _buildFeedbackSection(ThemeData theme) {
    final scheme = theme.colorScheme;
    final hasFeedback = _summary.therapistFeedback?.isNotEmpty == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.rate_review_rounded, color: scheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Therapist Feedback',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (_summary.feedbackUpdatedAt != null)
                      Text(
                        'Updated ${_formatDate(_summary.feedbackUpdatedAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _showFeedbackDialog,
                icon: Icon(hasFeedback ? Icons.edit_rounded : Icons.add_rounded, size: 18),
                label: Text(hasFeedback ? 'Edit' : 'Add'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
          if (hasFeedback) ...[
            const SizedBox(height: 16),
            Text(
              _summary.therapistFeedback!,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'Add feedback to help improve the AI model\'s responses for this patient.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _summary;
    final title = _patient?.fullName.isNotEmpty == true ? _patient!.fullName : 'Patient summary';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title),
        centerTitle: true,
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
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
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
                  if (_isTherapist) ...[
                    const SizedBox(height: 28),
                    _buildFeedbackSection(theme),
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
