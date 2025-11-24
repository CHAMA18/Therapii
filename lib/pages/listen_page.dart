import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/models/chat_conversation.dart';
import 'package:therapii/models/user.dart' as app_user;
import 'package:therapii/models/voice_checkin.dart';
import 'package:therapii/models/ai_conversation_summary.dart';
import 'package:therapii/pages/auth_welcome_page.dart';
import 'package:therapii/pages/my_patients_page.dart';
import 'package:therapii/pages/patient_chat_page.dart';
import 'package:therapii/pages/ai_summary_detail_page.dart';
import 'package:therapii/pages/therapist_voice_conversation_page.dart';
import 'package:therapii/services/chat_service.dart';
import 'package:therapii/services/invitation_service.dart';
import 'package:therapii/services/user_service.dart';
import 'package:therapii/services/voice_checkin_service.dart';
import 'package:therapii/services/ai_conversation_service.dart';
import 'package:therapii/widgets/shimmer_widgets.dart';
import 'package:therapii/widgets/common_settings_drawer.dart';

class ListenPage extends StatefulWidget {
  const ListenPage({super.key});

  @override
  State<ListenPage> createState() => _ListenPageState();
}

class _ListenPageState extends State<ListenPage> {
  final _invitationService = InvitationService();
  final _userService = UserService();
  final _chatService = ChatService();
  final _voiceService = VoiceCheckinService();
  final _aiService = AiConversationService();

  bool _loading = true;
  String? _error;
  List<app_user.User> _activePatients = [];
  String? _therapistId;
  app_user.User? _therapistUser;

  @override
  void initState() {
    super.initState();
    _loadActivePatients();
  }

  Future<void> _loadActivePatients() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final me = FirebaseAuthManager().currentUser;
      if (me == null) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWelcomePage(initialTab: AuthTab.login)),
          (route) => false,
        );
        return;
      }

      final therapistId = me.uid;
      final acceptedInvitations = await _invitationService.getAcceptedInvitationsForTherapist(therapistId);
      final patientIds = acceptedInvitations.map((inv) => inv.patientId).whereType<String>().toSet().toList();
      final users = await _userService.getUsersByIds(patientIds);
      final therapistUser = await _userService.getUser(therapistId);

      final lookup = {for (final user in users) user.id: user};
      final orderedUsers = acceptedInvitations
          .map((inv) => lookup[inv.patientId])
          .whereType<app_user.User>()
          .toList();

      if (!mounted) return;
      setState(() {
        _therapistId = therapistId;
        _therapistUser = therapistUser;
        _activePatients = orderedUsers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _truncate(String text, {int max = 60}) {
    if (text.length <= max) return text;
    return '${text.substring(0, max).trim()}...';
  }

  String _formatMonthDay(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthLabel = months[date.month - 1];
    return '$monthLabel ${date.day}';
  }

  String _subtitleForConversation(ChatConversation? convo) {
    final lastAt = convo?.lastMessageAt;
    if (lastAt != null) {
      return 'Last Message ${_formatMonthDay(lastAt)}';
    }

    final lastMessage = (convo?.lastMessageText ?? '').trim();
    if (lastMessage.isNotEmpty) {
      return _truncate(lastMessage, max: 40);
    }

    return 'Last Message —';
  }

  Widget _buildPatientTile(app_user.User user) {
    final displayName = user.fullName.isNotEmpty ? user.fullName : user.email;
    final therapistId = _therapistId;

    if (therapistId == null) {
      return _ListenPatientTile(
        name: displayName,
        lastMessage: 'Last Message —',
        onTap: null,
      );
    }

    return StreamBuilder<ChatConversation?>(
      stream: _chatService.streamConversation(therapistId: therapistId, patientId: user.id),
      builder: (context, snapshot) {
        final subtitle = _subtitleForConversation(snapshot.data);
        return _ListenPatientTile(
          name: displayName,
          lastMessage: subtitle,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PatientChatPage(otherUser: user),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startTherapistRecordingFlow() async {
    if (_activePatients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active patients to record for.')));
      return;
    }

    app_user.User? selected = _activePatients.first;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Record for patient', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                DropdownButtonFormField<app_user.User>(
                  value: selected,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Select patient'),
                  items: _activePatients
                      .map((u) => DropdownMenuItem(
                            value: u,
                            child: Text(u.fullName.isNotEmpty ? u.fullName : u.email),
                          ))
                      .toList(),
                  onChanged: (v) => setSheetState(() => selected = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    icon: const Icon(Icons.mic),
                    label: const Text('Start recording'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && mounted && selected != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TherapistVoiceConversationPage(patient: selected!)),
      );
    }
  }


  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final therapist = _therapistUser;
    final authUser = FirebaseAuthManager().currentUser;

    String resolveName() {
      final firstName = therapist?.firstName.trim() ?? '';
      if (firstName.isNotEmpty) return firstName;
      final fullName = therapist?.fullName.trim() ?? '';
      if (fullName.isNotEmpty) return fullName;
      final email = therapist?.email.trim().isNotEmpty == true
          ? therapist!.email
          : authUser?.email ?? '';
      if (email.isNotEmpty) return email;
      return 'Therapist';
    }

    final displayName = resolveName();
    final fallbackInitial = () {
      final email = authUser?.email ?? '';
      if (email.isEmpty) return 'T';
      final chars = email.characters;
      return chars.isNotEmpty ? chars.first.toUpperCase() : 'T';
    }();
    final initials = displayName.characters.isNotEmpty
        ? displayName.characters.first.toUpperCase()
        : fallbackInitial;
    final patientCount = _activePatients.length;

    String summary() {
      if (_loading) {
        return 'Gathering the latest updates from your patients and AI copilot. Hang tight for a moment.';
      }
      if (patientCount == 0) {
        return 'Invite patients to Therapii to unlock voice updates, transcripts, and real-time messaging in one place.';
      }
      final label = patientCount == 1 ? 'active patient' : 'active patients';
      return 'You are supporting $patientCount $label. Tap any card below to continue exactly where you left off.';
    }

    ButtonStyle buildButtonStyle({
      required Color background,
      required Color foreground,
      Color? disabledBackground,
      Color? disabledForeground,
    }) {
      return FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ).copyWith(
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return disabledBackground ?? background.withOpacity(0.6);
          }
          return background;
        }),
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return disabledForeground ?? foreground.withOpacity(0.6);
          }
          return foreground;
        }),
        overlayColor: MaterialStatePropertyAll(Colors.white.withOpacity(0.08)),
      );
    }

    Widget decorativeOrb({
      required double size,
      required Alignment alignment,
      required double opacity,
    }) {
      final base = Color.lerp(scheme.primary, Colors.black, 0.45) ?? scheme.primary;
      return Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: base.withOpacity(opacity),
            boxShadow: [
              BoxShadow(color: base.withOpacity(opacity * 0.6), blurRadius: 40, spreadRadius: 12),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(scheme.primary, Colors.black, 0.35) ?? scheme.primary,
              Color.lerp(scheme.primaryContainer, scheme.secondary, 0.25) ?? scheme.primaryContainer,
              Color.lerp(scheme.secondary, scheme.surface, 0.06) ?? scheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Color.lerp(scheme.primary, Colors.black, 0.55)?.withOpacity(0.32) ?? scheme.primary.withOpacity(0.32),
              blurRadius: 60,
              offset: const Offset(0, 26),
              spreadRadius: -12,
            ),
          ],
        ),
        child: Stack(
          children: [
            decorativeOrb(size: 240, alignment: const Alignment(1.1, -1.1), opacity: 0.16),
            decorativeOrb(size: 180, alignment: const Alignment(-1.2, 1.1), opacity: 0.1),
            Container(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 26),
              foregroundDecoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.14), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(color: Colors.white.withOpacity(0.38)),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, $displayName',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              summary(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withOpacity(0.86),
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _loadActivePatients(),
                        style: buildButtonStyle(
                          background: Color.lerp(scheme.primary, Colors.black, 0.42) ?? scheme.primary,
                          foreground: Colors.white,
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refresh'),
                      ),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const MyPatientsPage()),
                        ),
                        style: buildButtonStyle(
                          background: Color.lerp(scheme.primaryContainer, Colors.black, 0.32) ?? scheme.primaryContainer,
                          foreground: Color.lerp(scheme.onPrimaryContainer, Colors.white, 0.75) ?? Colors.white,
                          disabledBackground: Color.lerp(scheme.primaryContainer, Colors.black, 0.12),
                          disabledForeground: Color.lerp(scheme.onPrimaryContainer, Colors.white, 0.45),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Open chat'),
                      ),
                      FilledButton.icon(
                        onPressed: _activePatients.isEmpty ? null : _startTherapistRecordingFlow,
                        style: buildButtonStyle(
                          background: Color.lerp(scheme.primary, Colors.black, 0.18) ?? scheme.primary,
                          foreground: Colors.white,
                          disabledBackground: Color.lerp(scheme.primary, Colors.black, 0.08),
                        ),
                        icon: const Icon(Icons.mic_outlined),
                        label: const Text('Recorded conversation'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: scheme.error.withOpacity(0.28)),
          boxShadow: [
            BoxShadow(color: scheme.error.withOpacity(0.2), blurRadius: 28, offset: const Offset(0, 18), spreadRadius: -6),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: scheme.error.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.warning_rounded, color: scheme.error),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'We hit a snag syncing your workspace.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Something unexpected happened.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer.withOpacity(0.82),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: () => _loadActivePatients(),
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: const Text('Try again'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyPatientsPage()),
                  ),
                  child: const Text('Open patient hub'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? headerAction,
    Color? accentColor,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = accentColor ?? scheme.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          color: Color.lerp(scheme.surface, scheme.primaryContainer.withOpacity(0.32), 0.18) ?? scheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: scheme.outline.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 38, offset: const Offset(0, 24), spreadRadius: -10),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: accent),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (headerAction != null) ...[
                    const SizedBox(width: 12),
                    headerAction,
                  ],
                ],
              ),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivePatientsCard(BuildContext context) {
    final patientCount = _activePatients.length;
    final subtitle = _loading
        ? 'Syncing your patient roster and chat history. This only takes a moment.'
        : patientCount == 0
            ? 'No active patients yet. Share an invitation code to begin collaborating.'
            : 'You currently support $patientCount ${patientCount == 1 ? 'patient' : 'patients'}. Tap a profile to open their space.';

    Widget body;
    if (_loading) {
      body = Column(
        children: const [
          ShimmerListTile(),
          SizedBox(height: 12),
          ShimmerListTile(),
        ],
      );
    } else if (patientCount == 0) {
      body = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share your therapist invitation code from the My Patients hub to connect with clients instantly.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyPatientsPage()),
                  ),
                  icon: const Icon(Icons.key_outlined),
                  label: const Text('Generate invite'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _loadActivePatients(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      final tiles = <Widget>[];
      for (var i = 0; i < _activePatients.length; i++) {
        tiles.add(_buildPatientTile(_activePatients[i]));
        if (i != _activePatients.length - 1) {
          tiles.add(const SizedBox(height: 12));
        }
      }
      body = Column(children: tiles);
    }

    return _buildSectionCard(
      context: context,
      icon: Icons.health_and_safety_outlined,
      title: 'Active patients',
      subtitle: subtitle,
      headerAction: OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MyPatientsPage()),
        ),
        icon: const Icon(Icons.people_outline),
        label: const Text('Manage'),
      ),
      child: body,
    );
  }

  Widget _buildVoiceCheckinsCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final therapistId = _therapistId;
    if (therapistId == null) {
      return _buildSectionCard(
        context: context,
        icon: Icons.mic_rounded,
        title: 'Recent voice check-ins',
        subtitle: 'Link a patient to begin receiving voice reflections and actionable updates.',
        child: const SizedBox.shrink(),
      );
    }

    final patientLookup = {for (final p in _activePatients) p.id: p};

    return _buildSectionCard(
      context: context,
      icon: Icons.mic_rounded,
      title: 'Recent voice check-ins',
      subtitle: 'Review recorded reflections and open them in a new tab to listen or download.',
      headerAction: FilledButton.tonalIcon(
        onPressed: _activePatients.isEmpty ? null : _startTherapistRecordingFlow,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Record'),
      ),
      accentColor: scheme.error,
      child: StreamBuilder<List<VoiceCheckin>>(
        stream: _voiceService.streamTherapistCheckins(therapistId: therapistId, limit: 20),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: const [
                ShimmerListTile(),
                SizedBox(height: 12),
                ShimmerListTile(),
              ],
            );
          }
          if (snapshot.hasError) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.error.withOpacity(0.25)),
              ),
              child: Text(
                'Failed to load voice check-ins. Please try again in a moment.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
              ),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outline.withOpacity(0.12)),
              ),
              child: Text(
                'No voice check-ins yet. Encourage patients to send quick reflections so you can respond asynchronously.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.72),
                    ),
              ),
            );
          }

          final children = <Widget>[];
          for (var i = 0; i < items.length; i++) {
            final c = items[i];
            final patient = patientLookup[c.patientId];
            final name = patient == null
                ? 'Unknown patient'
                : (patient.fullName.isNotEmpty ? patient.fullName : patient.email);
            children.add(_VoiceCheckinTile(
              name: name,
              dateLabel: _formatMonthDay(c.createdAt),
              duration: Duration(seconds: c.durationSeconds),
              onOpen: () async {
                final uri = Uri.tryParse(c.audioUrl);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ));
            if (i != items.length - 1) {
              children.add(const SizedBox(height: 12));
            }
          }
          return Column(children: children);
        },
      ),
    );
  }

  Widget _buildTranscriptsCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final therapistId = _therapistId;
    if (therapistId == null) {
      return _buildSectionCard(
        context: context,
        icon: Icons.article_outlined,
        title: 'Transcripts',
        subtitle: 'Once your patients begin sharing voice reflections, AI transcripts will appear here for quick review.',
        child: const SizedBox.shrink(),
      );
    }

    final patientLookup = {for (final p in _activePatients) p.id: p};

    return _buildSectionCard(
      context: context,
      icon: Icons.article_outlined,
      title: 'Transcripts',
      subtitle: 'Review AI-assisted conversation summaries to capture insights and action items.',
      child: StreamBuilder<List<AiConversationSummary>>(
        stream: _aiService.streamTherapistSummaries(therapistId: therapistId, limit: 20),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              children: const [
                ShimmerListTile(),
                SizedBox(height: 12),
                ShimmerListTile(),
              ],
            );
          }
          if (snapshot.hasError) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.error.withOpacity(0.25)),
              ),
              child: Text(
                'Failed to load transcripts. Please refresh to try again.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
              ),
            );
          }
          final summaries = snapshot.data ?? [];
          if (summaries.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outline.withOpacity(0.12)),
              ),
              child: Text(
                'No transcripts yet. Once your patients share updates, AI summaries will appear here for quick review.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.72),
                    ),
              ),
            );
          }

          final children = <Widget>[];
          for (var i = 0; i < summaries.length; i++) {
            final s = summaries[i];
            final patient = patientLookup[s.patientId];
            final name = patient == null
                ? 'Unknown patient'
                : (patient.fullName.isNotEmpty ? patient.fullName : patient.email);
            children.add(_AiSummaryTile(
              name: name,
              dateLabel: _formatMonthDay(s.createdAt),
              snippet: _truncate(s.summary, max: 70),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AiSummaryDetailPage(summary: s)),
              ),
            ));
            if (i != summaries.length - 1) {
              children.add(const SizedBox(height: 12));
            }
          }
          return Column(children: children);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      drawer: const CommonSettingsDrawer(),
      body: SafeArea(
        child: Builder(
          builder: (innerContext) => RefreshIndicator(
            onRefresh: _loadActivePatients,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Scaffold.of(innerContext).openDrawer(),
                            icon: const Icon(Icons.menu),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your Therapii Space',
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const MyPatientsPage()),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 44),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            ),
                            icon: const Icon(Icons.people_outline),
                            label: const Text('My patients'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildHeroCard(context),
                      const SizedBox(height: 24),
                      if (_error != null)
                        _buildErrorCard(context)
                      else ...[
                        _buildActivePatientsCard(context),
                        const SizedBox(height: 24),
                        _buildVoiceCheckinsCard(context),
                        const SizedBox(height: 24),
                        _buildTranscriptsCard(context),
                      ],
                      const SizedBox(height: 36),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListenPatientTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final VoidCallback? onTap;
  const _ListenPatientTile({required this.name, required this.lastMessage, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(20);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        splashColor: scheme.primary.withOpacity(0.08),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.lerp(scheme.surface, scheme.primaryContainer, 0.32) ?? scheme.surface,
                Color.lerp(scheme.surfaceVariant, scheme.primaryContainer.withOpacity(0.4), 0.4) ?? scheme.surfaceVariant,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: radius,
            border: Border.all(color: scheme.outline.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 12), spreadRadius: -6),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withOpacity(0.14),
                    border: Border.all(color: scheme.primary.withOpacity(0.22)),
                  ),
                  child: Icon(Icons.person_outline, color: scheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        lastMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.7),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.28),
                    border: Border.all(color: Colors.white.withOpacity(0.32)),
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: scheme.primary.withOpacity(0.9)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceCheckinTile extends StatelessWidget {
  final String name;
  final String dateLabel;
  final Duration duration;
  final VoidCallback? onOpen;
  const _VoiceCheckinTile({required this.name, required this.dateLabel, required this.duration, this.onOpen});

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(16);
    final borderColor = colorScheme.outline.withOpacity(0.2);
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onOpen,
        child: Ink(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3))],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const CircleAvatar(radius: 24, backgroundColor: Color(0xFFE9EAED), child: Icon(Icons.mic, color: Colors.grey)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('$dateLabel • ${_formatDuration(duration)}',
                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                  ]),
                ),
                const SizedBox(width: 12),
                IconButton(onPressed: onOpen, icon: const Icon(Icons.open_in_new), color: theme.colorScheme.primary, tooltip: 'Open audio'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiSummaryTile extends StatelessWidget {
  final String name;
  final String dateLabel;
  final String snippet;
  final VoidCallback? onTap;
  const _AiSummaryTile({required this.name, required this.dateLabel, required this.snippet, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(16);
    final borderColor = colorScheme.outline.withOpacity(0.2);
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3))],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              CircleAvatar(radius: 24, backgroundColor: colorScheme.surfaceVariant, child: Icon(Icons.notes_rounded, color: colorScheme.onSurfaceVariant)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(dateLabel, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                  const SizedBox(height: 6),
                  Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                ]),
              ),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward_ios_rounded, size: 18, color: colorScheme.onSurface.withOpacity(0.6)),
            ]),
          ),
        ),
      ),
    );
  }
}
