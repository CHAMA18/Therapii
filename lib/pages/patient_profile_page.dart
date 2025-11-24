import 'package:flutter/material.dart';
import 'package:therapii/models/ai_conversation_summary.dart';
import 'package:therapii/models/chat_message.dart';
import 'package:therapii/models/user.dart' as app_user;
import 'package:therapii/models/voice_checkin.dart';
import 'package:therapii/pages/ai_summary_detail_page.dart';
import 'package:therapii/pages/patient_chat_page.dart';
import 'package:therapii/services/ai_conversation_service.dart';
import 'package:therapii/services/chat_service.dart';
import 'package:therapii/services/voice_checkin_service.dart';
import 'package:therapii/widgets/primary_button.dart';

class PatientProfilePage extends StatefulWidget {
  final app_user.User patient;
  final String therapistId;
  const PatientProfilePage({super.key, required this.patient, required this.therapistId});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final _chatService = ChatService();
  final _aiConversationService = AiConversationService();
  final _voiceCheckinService = VoiceCheckinService();
  final _scrollController = ScrollController();
  final _activeConversationsKey = GlobalKey();
  final _recentConversationsKey = GlobalKey();
  final _summariesKey = GlobalKey();
  final _voiceCheckinsKey = GlobalKey();

  Future<void> _openChat() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientChatPage(otherUser: widget.patient),
      ),
    );
  }

  Future<void> _scrollTo(GlobalKey key) async {
    final context = key.currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final patient = widget.patient;
    final displayName = patient.fullName.trim().isNotEmpty ? patient.fullName : patient.email;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primaryContainer,
                      scheme.primary,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                          color: scheme.onPrimaryContainer,
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.onPrimary.withOpacity(0.1),
                            padding: const EdgeInsets.all(10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        Chip(
                          backgroundColor: scheme.onPrimary.withOpacity(0.18),
                          label: Text(
                            'Patient Profile',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: scheme.surface.withOpacity(0.2),
                          backgroundImage: (patient.avatarUrl ?? '').isNotEmpty ? NetworkImage(patient.avatarUrl!) : null,
                          child: (patient.avatarUrl ?? '').isNotEmpty
                              ? null
                              : Icon(Icons.person, size: 40, color: scheme.onPrimary.withOpacity(0.8)),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                patient.email,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onPrimary.withOpacity(0.8),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              if ((patient.phoneNumber ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  patient.phoneNumber!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onPrimary.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _QuickLinkButton(
                          label: 'Active AI Conversations',
                          icon: Icons.chat_bubble_rounded,
                          onTap: () => _scrollTo(_activeConversationsKey),
                        ),
                        _QuickLinkButton(
                          label: 'Recent AI Conversations',
                          icon: Icons.forum_outlined,
                          onTap: () => _scrollTo(_recentConversationsKey),
                        ),
                        _QuickLinkButton(
                          label: 'AI Summaries',
                          icon: Icons.summarize_rounded,
                          onTap: () => _scrollTo(_summariesKey),
                        ),
                        _QuickLinkButton(
                          label: 'Voice Check-ins',
                          icon: Icons.mic_rounded,
                          onTap: () => _scrollTo(_voiceCheckinsKey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      key: _activeConversationsKey,
                      child: _SectionCard(
                        title: 'Active AI Conversations',
                        subtitle: 'Ongoing AI therapy conversations with this patient.',
                        color: scheme.primary,
                        child: StreamBuilder<List<AiConversationSummary>>(
                          stream: _aiConversationService.streamPatientSummaries(patientId: patient.id, limit: 5),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const _LoadingInfo(text: 'Loading active conversations…');
                            }
                            final conversations = snapshot.data ?? [];
                            if (conversations.isEmpty) {
                              return Text(
                                'No active AI conversations at the moment.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface.withOpacity(0.7),
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final conv in conversations.take(5)) ...[
                                  _ConversationCard(
                                    summary: conv,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => AiSummaryDetailPage(summary: conv)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      key: _recentConversationsKey,
                      child: _SectionCard(
                        title: 'Recent AI Conversations',
                        subtitle: 'Latest messages between you and this patient.',
                        color: scheme.secondary,
                        child: StreamBuilder<List<ChatMessage>>(
                          stream: _chatService.streamMessages(
                            therapistId: widget.therapistId,
                            patientId: patient.id,
                            limit: 120,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const _LoadingInfo(text: 'Fetching recent messages…');
                            }
                            final messages = snapshot.data ?? [];
                            if (messages.isEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No messages yet. Start the conversation any time.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  PrimaryButton(
                                    label: 'Compose Message',
                                    onPressed: _openChat,
                                    leadingIcon: Icons.edit_rounded,
                                  ),
                                ],
                              );
                            }
                            final preview = messages.length <= 3
                                ? messages
                                : messages.sublist(messages.length - 3, messages.length);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final m in preview.reversed) ...[
                                  _MessagePreview(message: m, therapistId: widget.therapistId),
                                  const SizedBox(height: 12),
                                ],
                                const SizedBox(height: 4),
                                PrimaryButton(
                                  label: 'View Message History',
                                  onPressed: _openChat,
                                  leadingIcon: Icons.forum_outlined,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      key: _summariesKey,
                      child: _SectionCard(
                        title: 'Recent AI Summaries',
                        subtitle: 'Latest AI-generated therapy session summaries.',
                        color: scheme.tertiary,
                        child: StreamBuilder<List<AiConversationSummary>>(
                          stream: _aiConversationService.streamPatientSummaries(patientId: patient.id, limit: 5),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const _LoadingInfo(text: 'Loading summaries…');
                            }
                            final summaries = snapshot.data ?? [];
                            if (summaries.isEmpty) {
                              return Text(
                                'No AI summaries available yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface.withOpacity(0.7),
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final sum in summaries.take(5)) ...[
                                  _ConversationCard(
                                    summary: sum,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => AiSummaryDetailPage(summary: sum)),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      key: _voiceCheckinsKey,
                      child: _SectionCard(
                        title: 'Recent Voice Check-ins',
                        subtitle: 'Audio recordings submitted by the patient.',
                        color: scheme.error,
                        child: StreamBuilder<List<VoiceCheckin>>(
                          stream: _voiceCheckinService.streamPatientCheckins(therapistId: widget.therapistId, patientId: patient.id, limit: 5),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const _LoadingInfo(text: 'Loading voice check-ins…');
                            }
                            final checkins = snapshot.data ?? [];
                            if (checkins.isEmpty) {
                              return Text(
                                'No voice check-ins recorded yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurface.withOpacity(0.7),
                                ),
                              );
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final checkin in checkins.take(5)) ...[
                                  _VoiceCheckinCard(checkin: checkin),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Color color;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.blur_on_rounded, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _LoadingInfo extends StatelessWidget {
  final String text;
  const _LoadingInfo({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _QuickLinkButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _QuickLinkButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        foregroundColor: scheme.onSurface,
        backgroundColor: scheme.surfaceVariant.withOpacity(0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _MessagePreview extends StatelessWidget {
  final ChatMessage message;
  final String therapistId;
  const _MessagePreview({required this.message, required this.therapistId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isTherapist = message.senderId == therapistId;
    final prefix = isTherapist ? 'You' : 'Patient';
    final date = message.sentAt;
    final formatted = '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final text = message.text.trim().isEmpty ? '(Attachment)' : message.text.trim();
    final truncated = text.length > 90 ? '${text.substring(0, 87)}…' : text;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isTherapist ? scheme.primary.withOpacity(0.08) : scheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isTherapist ? Icons.account_circle : Icons.person_outline, size: 18, color: scheme.onSurface.withOpacity(0.75)),
              const SizedBox(width: 6),
              Text(
                '$prefix • $formatted',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurface.withOpacity(0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            truncated,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurface,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final AiConversationSummary summary;
  final VoidCallback onTap;
  const _ConversationCard({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = summary.createdAt;
    final formatted = '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final preview = summary.summary.length > 120 ? '${summary.summary.substring(0, 117)}…' : summary.summary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    formatted,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withOpacity(0.5)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              preview,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceCheckinCard extends StatelessWidget {
  final VoiceCheckin checkin;
  const _VoiceCheckinCard({required this.checkin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final date = checkin.createdAt;
    final formatted = '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final durationMinutes = checkin.durationSeconds ~/ 60;
    final durationSeconds = checkin.durationSeconds % 60;
    final durationStr = '$durationMinutes:${durationSeconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: scheme.errorContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.mic_rounded, color: scheme.error, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Check-in',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$formatted • $durationStr',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

