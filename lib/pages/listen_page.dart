import 'package:flutter/material.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/models/chat_conversation.dart';
import 'package:therapii/models/user.dart' as app_user;
import 'package:therapii/models/voice_checkin.dart';
import 'package:therapii/pages/auth_welcome_page.dart';
import 'package:therapii/pages/my_patients_page.dart';
import 'package:therapii/pages/patient_chat_page.dart';
import 'package:therapii/pages/therapist_voice_conversation_page.dart';
import 'package:therapii/services/chat_service.dart';
import 'package:therapii/services/invitation_service.dart';
import 'package:therapii/services/user_service.dart';
import 'package:therapii/services/voice_checkin_service.dart';
import 'package:therapii/widgets/shimmer_widgets.dart';
import 'package:therapii/pages/voice_checkin_detail_page.dart';
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

    final selected = await showModalBottomSheet<app_user.User>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecordPatientSelectionSheet(patients: _activePatients),
    );

    if (selected != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TherapistVoiceConversationPage(patient: selected)),
      );
    }
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
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? headerAction,
    Widget? child,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ),
              if (headerAction != null) ...[
                const SizedBox(width: 12),
                headerAction,
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
          if (child != null) ...[
            const SizedBox(height: 20),
            child,
          ],
        ],
      ),
    );
  }

  Widget _buildActivePatientsCard(BuildContext context) {
    final theme = Theme.of(context);
    final patientCount = _activePatients.length;
    final subtitle = _loading
        ? 'Syncing your patient roster and chat history.'
        : patientCount == 0
            ? 'No active patients yet. Share an invitation code to begin collaborating.'
            : null;

    return _buildSectionCard(
      context: context,
      icon: Icons.shield_outlined,
      iconColor: Colors.blue,
      title: 'Active patients',
      subtitle: subtitle,
      child: _loading
          ? const Column(
              children: [
                ShimmerListTile(),
                SizedBox(height: 12),
                ShimmerListTile(),
              ],
            )
          : patientCount == 0
              ? null
              : Column(
                  children: [
                    for (var i = 0; i < _activePatients.length; i++) ...[
                      _buildPatientTile(_activePatients[i]),
                      if (i != _activePatients.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
    );
  }

  Widget _buildInvitationCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share your therapist invitation code from the My Patients hub to connect with clients instantly.',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyPatientsPage()),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.key_outlined, size: 18),
            label: const Text('Generate invite'),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceCheckinsCard(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final therapistId = _therapistId;
    if (therapistId == null) {
      return _buildSectionCard(
        context: context,
        icon: Icons.mic,
        iconColor: Colors.red.shade400,
        title: 'Recent voice check-ins',
        subtitle: 'Link a patient to begin receiving voice reflections and actionable updates.',
      );
    }

    final patientLookup = {for (final p in _activePatients) p.id: p};

    return _buildSectionCard(
      context: context,
      icon: Icons.mic,
      iconColor: Colors.red.shade400,
      title: 'Recent voice check-ins',
      subtitle: 'Review recorded reflections and open them in a new tab to listen or download.',
      headerAction: FilledButton.icon(
        onPressed: _activePatients.isEmpty ? null : _startTherapistRecordingFlow,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        icon: const Icon(Icons.add_circle_outline, size: 18),
        label: const Text('Record'),
      ),
      child: StreamBuilder<List<VoiceCheckin>>(
        stream: _voiceService.streamTherapistCheckins(therapistId: therapistId, limit: 20),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Column(
              children: [
                ShimmerListTile(),
                SizedBox(height: 12),
                ShimmerListTile(),
              ],
            );
          }
          if (snapshot.hasError) {
            return Text(
              'Failed to load voice check-ins. Please try again in a moment.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.error,
              ),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Text(
              'No voice check-ins yet. Encourage patients to send quick reflections so you can respond asynchronously.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withOpacity(0.7),
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
              onOpen: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VoiceCheckinDetailPage(
                      checkin: c,
                      patient: patient,
                    ),
                  ),
                );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Your Therapii Space',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => showSettingsPopup(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (innerContext) => RefreshIndicator(
            onRefresh: _loadActivePatients,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Overview',
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => Navigator.of(context).push(
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
                      if (_error != null)
                        _buildErrorCard(context)
                      else ...[
                        _buildActivePatientsCard(context),
                        if (_activePatients.isEmpty && !_loading) ...[
                          const SizedBox(height: 20),
                          _buildInvitationCard(context),
                        ],
                        const SizedBox(height: 20),
                        _buildVoiceCheckinsCard(context),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
              ),
              child: Icon(Icons.person_outline, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
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
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
              ),
              child: Icon(Icons.mic, color: Colors.grey.shade700, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateLabel • ${_formatDuration(duration)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface.withOpacity(0.6)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new, size: 20),
              color: scheme.primary,
              tooltip: 'Open audio',
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordPatientSelectionSheet extends StatefulWidget {
  final List<app_user.User> patients;
  const _RecordPatientSelectionSheet({required this.patients});

  @override
  State<_RecordPatientSelectionSheet> createState() => _RecordPatientSelectionSheetState();
}

class _RecordPatientSelectionSheetState extends State<_RecordPatientSelectionSheet> {
  app_user.User? _selectedPatient;

  @override
  void initState() {
    super.initState();
    if (widget.patients.isNotEmpty) {
      _selectedPatient = widget.patients.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, -10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary.withValues(alpha: 0.1), scheme.primary.withValues(alpha: 0.05)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mic_rounded, size: 36, color: scheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Record Voice Check-in',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a patient to create a personalized voice note',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _FeatureMiniCard(
                  icon: Icons.record_voice_over_rounded,
                  label: 'Quick Notes',
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                _FeatureMiniCard(
                  icon: Icons.cloud_upload_outlined,
                  label: 'Auto-Save',
                  color: Colors.teal,
                ),
                const SizedBox(width: 12),
                _FeatureMiniCard(
                  icon: Icons.history_rounded,
                  label: 'Instant Access',
                  color: Colors.indigo,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.people_alt_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Select Patient',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
                      ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    itemCount: widget.patients.length,
                    itemBuilder: (context, index) {
                      final patient = widget.patients[index];
                      final isSelected = _selectedPatient?.id == patient.id;
                      final displayName = patient.fullName.isNotEmpty ? patient.fullName : patient.email;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: isSelected ? scheme.primary : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => setState(() => _selectedPatient = patient),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? scheme.primary : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected ? Colors.white.withValues(alpha: 0.2) : scheme.primary.withValues(alpha: 0.1),
                                    ),
                                    child: Center(
                                      child: Text(
                                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? Colors.white : scheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isSelected ? Colors.white : scheme.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          patient.email,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: isSelected ? Colors.white.withValues(alpha: 0.8) : scheme.onSurfaceVariant,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _selectedPatient == null ? null : () => Navigator.of(context).pop(_selectedPatient),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic_rounded, size: 22, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      'Start Recording',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FeatureMiniCard({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.9)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}


