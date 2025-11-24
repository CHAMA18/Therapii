import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/pages/auth_welcome_page.dart';
import 'package:therapii/pages/listen_page.dart';
import 'package:therapii/pages/new_patient_info_page.dart';
import 'package:therapii/pages/therapist_details_page.dart';
import 'package:therapii/pages/patient_chat_page.dart';
import 'package:therapii/pages/patient_profile_page.dart';
import 'package:therapii/services/invitation_service.dart';
import 'package:therapii/services/user_service.dart';
import 'package:therapii/models/invitation_code.dart';
import 'package:therapii/models/user.dart' as AppUser;
import 'package:therapii/widgets/shimmer_widgets.dart';
import 'package:therapii/widgets/app_drawer.dart';
import 'package:therapii/widgets/common_settings_drawer.dart';
import 'package:therapii/services/chat_service.dart';
import 'package:therapii/models/chat_conversation.dart';
import 'package:therapii/theme_mode_controller.dart';
import 'package:therapii/services/ai_conversation_service.dart';
import 'package:therapii/models/ai_conversation_summary.dart';
import 'package:therapii/pages/ai_summary_detail_page.dart';
import 'package:therapii/services/voice_checkin_service.dart';
import 'package:therapii/models/voice_checkin.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:therapii/widgets/therapist_approval_gate.dart';

enum TopNavSection { patients, listen }

class MyPatientsPage extends StatefulWidget {
  const MyPatientsPage({super.key});

  @override
  State<MyPatientsPage> createState() => _MyPatientsPageState();
}

class _MyPatientsPageState extends State<MyPatientsPage> {
  TopNavSection _selected = TopNavSection.patients;

  final _invitationService = InvitationService();
  final _userService = UserService();
  final _chatService = ChatService();
  final _aiService = AiConversationService();

  bool _loading = true;
  String? _error;
  List<AppUser.User> _activePatients = [];
  List<InvitationCode> _pendingInvites = [];
  String? _therapistId;
  bool _showAllPatients = false;
  String? _approvalStatus;
  DateTime? _approvalRequestedAt;
  bool _checkingApproval = false;
  bool _signingOut = false;

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

  Widget _buildPatientTile(AppUser.User user) {
    final displayName = user.fullName.isNotEmpty ? user.fullName : user.email;
    final therapistId = _therapistId;
    final openChat = () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PatientChatPage(otherUser: user),
          ),
        );

    if (therapistId == null) {
      return _PatientTile(
        name: displayName,
        lastMessage: 'Last Message —',
        onOpenChat: openChat,
      );
    }

    return StreamBuilder<ChatConversation?>(
      stream: _chatService.streamConversation(
        therapistId: therapistId,
        patientId: user.id,
      ),
      builder: (context, snapshot) {
        final convo = snapshot.data;
        final subtitle = _subtitleForConversation(convo);
        final unread = convo?.therapistUnreadCount ?? 0;
        return _PatientTile(
          name: displayName,
          lastMessage: subtitle,
          unreadCount: unread,
          onOpenChat: openChat,
          onViewDetails: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PatientProfilePage(
                patient: user,
                therapistId: therapistId,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveAiConversationsSection(BuildContext context) {
    final therapistId = _therapistId;
    if (therapistId == null) {
      return const SizedBox.shrink();
    }

    final patientLookup = {
      for (final patient in _activePatients) patient.id: patient,
    };

    return StreamBuilder<List<ChatConversation>>(
      stream: _chatService.streamTherapistConversations(
        therapistId: therapistId,
        limit: 20,
      ),
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
          final theme = Theme.of(context);
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Failed to load AI conversations. Please try again later.',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          );
        }

        final conversations = snapshot.data ?? [];
        if (conversations.isEmpty) {
          final theme = Theme.of(context);
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Text(
              'No active AI conversations yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
          );
        }

        final tiles = <Widget>[];
        for (var i = 0; i < conversations.length; i++) {
          final convo = conversations[i];
          final patient = patientLookup[convo.patientId];
          tiles.add(
            _AiConversationTile(
              name: _patientDisplayName(patient),
              subtitle: _subtitleForConversation(convo),
              unreadCount: convo.therapistUnreadCount,
              onTap: patient != null
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PatientChatPage(otherUser: patient),
                        ),
                      )
                  : null,
            ),
          );
          if (i != conversations.length - 1) {
            tiles.add(const SizedBox(height: 12));
          }
        }

        return Column(children: tiles);
      },
    );
  }

  Widget _buildAiSummariesSection(BuildContext context) {
    final therapistId = _therapistId;
    if (therapistId == null) {
      return const SizedBox.shrink();
    }

    final patientLookup = {for (final p in _activePatients) p.id: p};

    return StreamBuilder<List<AiConversationSummary>>(
      stream: _aiService.streamTherapistSummaries(therapistId: therapistId, limit: 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(children: const [ShimmerListTile(), SizedBox(height: 12), ShimmerListTile()]);
        }
        if (snapshot.hasError) {
          final theme = Theme.of(context);
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Failed to load AI summaries. Please try again later.',
                style: TextStyle(color: theme.colorScheme.onErrorContainer)),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          final theme = Theme.of(context);
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Text('No AI summaries yet.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
          );
        }

        final tiles = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          final s = items[i];
          final patient = patientLookup[s.patientId];
          tiles.add(_AiSummaryTile(
            name: _patientDisplayName(patient),
            dateLabel: _formatMonthDay(s.createdAt),
            snippet: _truncate(s.summary, max: 70),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => AiSummaryDetailPage(summary: s)),
            ),
          ));
          if (i != items.length - 1) tiles.add(const SizedBox(height: 12));
        }
        return Column(children: tiles);
      },
    );
  }

  Widget _buildVoiceCheckinsSection(BuildContext context) {
    final therapistId = _therapistId;
    if (therapistId == null) return const SizedBox.shrink();

    final patientLookup = {for (final p in _activePatients) p.id: p};
    final svc = VoiceCheckinService();

    return StreamBuilder<List<VoiceCheckin>>(
      stream: svc.streamTherapistCheckins(therapistId: therapistId, limit: 20),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(children: const [ShimmerListTile(), SizedBox(height: 12), ShimmerListTile()]);
        }
        if (snapshot.hasError) {
          final theme = Theme.of(context);
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Failed to load voice check-ins. Please try again later.',
                style: TextStyle(color: theme.colorScheme.onErrorContainer)),
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          final theme = Theme.of(context);
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Text('No voice check-ins yet.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
          );
        }

        final tiles = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          final c = items[i];
          final patient = patientLookup[c.patientId];
          final name = _patientDisplayName(patient);
          tiles.add(_VoiceCheckinTile(
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
          if (i != items.length - 1) tiles.add(const SizedBox(height: 12));
        }
        return Column(children: tiles);
      },
    );
  }

  String _patientDisplayName(AppUser.User? user) {
    if (user == null) return 'Unknown patient';
    if (user.fullName.isNotEmpty) {
      return user.fullName;
    }
    return user.email;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _confirmAndDelete(InvitationCode inv) async {
    final me = FirebaseAuthManager().currentUser;
    if (me == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete invitation?'),
        content: const Text('This will remove the invitation permanently. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _invitationService.deleteInvitation(invitationId: inv.id, therapistId: me.uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation deleted')));
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _loadDataInternal(silentApprovalCheck: false);
  }

  Future<void> _loadDataInternal({required bool silentApprovalCheck}) async {
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

      final therapistSnapshot = await FirebaseFirestore.instance.collection('therapists').doc(therapistId).get();
      final therapistData = therapistSnapshot.data() ?? <String, dynamic>{};
      final status = (therapistData['approval_status'] as String?)?.toLowerCase() ?? 'pending';
      final timestamp = (therapistData['approval_requested_at'] as Timestamp? ??
              therapistData['updated_at'] as Timestamp? ??
              therapistData['created_at'] as Timestamp?)
          ?.toDate();

      if (!mounted) return;
      setState(() {
        _therapistId = therapistId;
        _approvalStatus = status;
        _approvalRequestedAt = timestamp;
      });

      if (status != 'approved') {
        if (!mounted) return;
        setState(() {
          _activePatients = [];
          _pendingInvites = [];
          _loading = false;
          _showAllPatients = false;
        });
        return;
      }

      final invites = await _invitationService.getTherapistInvitations(therapistId);
      final accepted = invites.where((i) => i.isUsed && i.patientId != null).toList();
      final pending = invites.where((i) => !i.isUsed).toList();

      final patientIds = accepted.map((e) => e.patientId!).toSet().toList();
      final users = await _userService.getUsersByIds(patientIds);

      if (!mounted) return;
      setState(() {
        _activePatients = users;
        _pendingInvites = pending;
        _loading = false;
        _showAllPatients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshApprovalStatus() async {
    if (_checkingApproval) return;
    setState(() => _checkingApproval = true);
    await _loadDataInternal(silentApprovalCheck: true);
    if (!mounted) return;
    setState(() {
      _checkingApproval = false;
      _loading = false;
    });
  }

  Future<void> _openTherapistProfileEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TherapistDetailsPage()),
    );
    if (!mounted) return;
    await _loadDataInternal(silentApprovalCheck: true);
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await FirebaseAuthManager().signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWelcomePage(initialTab: AuthTab.login)),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const int maxVisiblePatients = 10;
    final bool hasMorePatients = _activePatients.length > maxVisiblePatients;
    final List<AppUser.User> patientsToDisplay =
        _showAllPatients || !hasMorePatients ? _activePatients : _activePatients.take(maxVisiblePatients).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: const CommonSettingsDrawer(),
      body: SafeArea(
        child: Builder(
          builder: (innerContext) {
            if (!_loading) {
              final status = (_approvalStatus ?? '').toLowerCase();
              if (status.isNotEmpty && status != 'approved') {
                return TherapistApprovalGate(
                  status: _approvalStatus ?? 'pending',
                  requestedAt: _approvalRequestedAt,
                  refreshing: _checkingApproval,
                  signingOut: _signingOut,
                  onRefresh: _refreshApprovalStatus,
                  onUpdateProfile: _openTherapistProfileEditor,
                  onSignOut: _signOut,
                );
              }
            }

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        _TopNav(
                          selected: _selected,
                          onMenuTap: () => Scaffold.of(innerContext).openDrawer(),
                          onPatientsTap: () => setState(() => _selected = TopNavSection.patients),
                          onListenTap: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const ListenPage()),
                          ),
                        ),
                          const SizedBox(height: 16),
                        Text(
                          'My Patients',
                          style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                        ),
                          const SizedBox(height: 8),
                        Text(
                          'Below is a list of all your active patients. Click the name of anyone to see more detail, or click the New Patient button to invite someone new.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                                height: 1.35,
                              ),
                        ),
                          const SizedBox(height: 16),
                          Row(
                          children: [
                            Text(
                              'Active patients',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const NewPatientInfoPage()),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.primary,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Invite New'),
                            ),
                          ],
                        ),
                          const SizedBox(height: 8),
                          if (_loading) ...[
                            const SizedBox(height: 8),
                            Column(
                              children: [
                                for (int i = 0; i < 3; i++) ...[
                                  const ShimmerListTile(),
                                  const SizedBox(height: 12),
                                ],
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Text(
                                      'Invitations sent',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const Spacer(),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                for (int i = 0; i < 2; i++) ...[
                                  const ShimmerInviteTile(),
                                  const SizedBox(height: 12),
                                ],
                              ],
                            ),
                          ] else if (_error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(color: theme.colorScheme.onErrorContainer),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            if (_activePatients.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
                                ),
                                child: Text(
                                  'No active patients yet.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                                      ),
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final u in patientsToDisplay) ...[
                                    _buildPatientTile(u),
                                    const SizedBox(height: 12),
                                  ],
                                  if (hasMorePatients && !_showAllPatients)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        onPressed: () => setState(() => _showAllPatients = true),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          textStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        child: const Text('See All'),
                                      ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 24),
                            if (_pendingInvites.isNotEmpty) ...[
                              Row(
                                children: [
                                  Text(
                                    'Invitations sent',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const Spacer(),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: [
                                  for (final inv in _pendingInvites) ...[
                                    _InviteTile(
                                      invitation: inv,
                                      onDelete: () => _confirmAndDelete(inv),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ],
                              ),
                            ],
                          ],
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopNav extends StatelessWidget {
  final TopNavSection selected;
  final VoidCallback onMenuTap;
  final VoidCallback onPatientsTap;
  final VoidCallback onListenTap;
  const _TopNav({
    required this.selected,
    required this.onMenuTap,
    required this.onPatientsTap,
    required this.onListenTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Row(
      children: [
        IconButton(
          onPressed: onMenuTap,
          icon: const Icon(Icons.menu),
          color: theme.colorScheme.onSurface,
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.6),
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _HeaderTab(label: 'My Patients', selected: selected == TopNavSection.patients, color: primary, onTap: onPatientsTap),
              _HeaderTab(label: 'Listen', selected: selected == TopNavSection.listen, color: primary, onTap: onListenTap),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;
  const _HeaderTab({required this.label, required this.selected, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactiveColor = theme.colorScheme.onSurface.withOpacity(0.6);
    final textStyle = theme.textTheme.titleLarge?.copyWith(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? color : inactiveColor,
        );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 6),
        decoration: selected
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: color, width: 3),
                ),
              )
            : null,
        child: Text(label, style: textStyle),
      ),
    );
  }
}

class _PatientTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final Color? blue;
  final VoidCallback? onViewDetails;
  final VoidCallback? onOpenChat;
  final int unreadCount;
  const _PatientTile({
    required this.name,
    required this.lastMessage,
    this.blue,
    this.onViewDetails,
    this.onOpenChat,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(16);
    final borderColor = colorScheme.outline.withOpacity(0.2);
    final surfaceColor = colorScheme.surface;
    final blueColor = blue ?? colorScheme.primary;
    final subtitleStyle = theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.6));

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onViewDetails,
        child: Ink(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: borderRadius,
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.surfaceVariant,
                  child: Icon(Icons.person, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(lastMessage, style: subtitleStyle),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onOpenChat,
                      icon: const Icon(Icons.chat_bubble_outline, size: 20),
                      color: blueColor,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 6),
                      _UnreadBadge(count: unreadCount),
                    ],
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: onOpenChat,
                      style: TextButton.styleFrom(
                        foregroundColor: blueColor,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      child: const Text('Message History'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiConversationTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final int unreadCount;
  final VoidCallback? onTap;
  const _AiConversationTile({
    required this.name,
    required this.subtitle,
    this.unreadCount = 0,
    this.onTap,
  });

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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.surfaceVariant,
                  child: Icon(Icons.smart_toy_outlined, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 12),
                  _UnreadBadge(count: unreadCount),
                ],
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward_ios_rounded, size: 18, color: colorScheme.onSurface.withOpacity(0.6)),
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
  const _VoiceCheckinTile({
    required this.name,
    required this.dateLabel,
    required this.duration,
    this.onOpen,
  });

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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFE9EAED),
                child: Icon(Icons.mic, color: Colors.grey),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateLabel • ${_formatDuration(duration)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new),
                color: theme.colorScheme.primary,
                tooltip: 'Open audio',
              ),
            ]),
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
  const _AiSummaryTile({
    required this.name,
    required this.dateLabel,
    required this.snippet,
    this.onTap,
  });

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
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.surfaceVariant,
                  child: Icon(Icons.notes_rounded, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(dateLabel, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                      const SizedBox(height: 6),
                      Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward_ios_rounded, size: 18, color: colorScheme.onSurface.withOpacity(0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final display = count > 99 ? '99+' : count.toString();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        display,
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  final InvitationCode invitation;
  final VoidCallback? onDelete;
  const _InviteTile({required this.invitation, this.onDelete});

  String _remainingText(DateTime now, DateTime expiry) {
    final diff = expiry.difference(now);
    if (diff.isNegative) return 'Expired';
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours >= 1) {
      return 'Expires in ${hours}h ${minutes}m';
    }
    return 'Expires in ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final borderColor = theme.colorScheme.outlineVariant.withOpacity(0.4);
    final now = DateTime.now();
    final showCode = now.isBefore(invitation.expiresAt);
    final secondary = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7));

    return Material(
      color: theme.colorScheme.surface,
      shape: border,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(side: BorderSide(color: borderColor), borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.surfaceVariant,
              child: Icon(Icons.mail_outline, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  invitation.patientFirstName,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(invitation.patientEmail, style: secondary),
                const SizedBox(height: 6),
                if (showCode)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Code: ${invitation.code}',
                          style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(_remainingText(now, invitation.expiresAt), style: secondary),
                    ],
                  )
                else
                  Text('Invitation expired', style: secondary),
              ]),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Delete invitation',
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerBadge extends StatelessWidget {
  final String text;
  const _CornerBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF09B58),
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

// Drawer and static content were extracted to CommonSettingsDrawer for reuse.
