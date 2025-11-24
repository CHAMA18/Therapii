import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/pages/admin_settings_page.dart';
import 'package:therapii/pages/auth_welcome_page.dart';
import 'package:therapii/pages/therapist_approvals_page.dart';
import 'package:therapii/utils/admin_access.dart';
import 'package:therapii/widgets/app_drawer.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _humanConversationCount = 0;
  int _aiConversationCount = 0;
  bool _loadingCounts = true;
  String? _countsError;
  late final FirebaseFirestore _firestore;
  late final FirebaseAuth _auth;
  StreamSubscription? _authSubscription;
  final ScrollController _approvalsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
    _authSubscription = _auth.userChanges().listen((user) {
      if (!AdminAccess.isAdminEmail(user?.email)) {
        if (!mounted) return;
        Navigator.of(context).maybePop();
      }
    });
    _loadCounts();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _approvalsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    setState(() {
      _loadingCounts = true;
      _countsError = null;
    });
    try {
      final humanAgg = await _firestore.collection('conversations').count().get();
      final aiAgg = await _firestore.collection('ai_conversation_summaries').count().get();
      if (!mounted) return;
      setState(() {
        _humanConversationCount = humanAgg.count ?? 0;
        _aiConversationCount = aiAgg.count ?? 0;
        _loadingCounts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _countsError = 'Unable to load conversation totals. $e';
        _loadingCounts = false;
      });
    }
  }

  Future<void> _approveTherapist(String therapistId) async {
    final currentUser = FirebaseAuthManager().currentUser;
    try {
      await _firestore.collection('therapists').doc(therapistId).set({
        'approval_status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
        'approved_by': currentUser?.uid,
        'approved_by_email': currentUser?.email,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapist approved successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve therapist. $e')),
      );
    }
  }

  void _showTherapistDetails(Map<String, dynamic> data) {
    final educations = _resolveEducationSummaries(data);
    final licensure = List<String>.from(data['state_licensures'] ?? const <String>[]);
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final padding = EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          top: 24,
        );
        return Padding(
          padding: padding,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['full_name'] ?? 'Therapist details',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _detailRow('Practice', data['practice_name']),
                _detailRow('Location', _formatLocation(data)),
                _detailRow('Email', data['contact_email']),
                _detailRow('Phone', data['contact_phone']),
                if (licensure.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('State Licensure', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: licensure
                        .map((item) => Chip(
                              label: Text(item),
                              backgroundColor: theme.colorScheme.surfaceVariant,
                            ))
                        .toList(),
                  ),
                ],
                if (educations.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Education', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in educations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('• $entry', style: theme.textTheme.bodyMedium),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, dynamic value) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('$value', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: _loadingCounts ? null : _loadCounts,
            icon: _loadingCounts
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh metrics',
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMetricsRow(theme),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Therapist approvals',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TherapistApprovalsPage()),
                      );
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('View All'),
                    style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Review and approve therapists before granting access to the clinician dashboard.',
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore.collection('therapists').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _errorState(theme, 'Unable to load therapist submissions. ${snapshot.error}');
                    }
                    final docs = snapshot.data?.docs ?? [];
                    final pending = docs.where((doc) {
                      final status = (doc.data()['approval_status'] as String?)?.toLowerCase();
                      return status == null || status == 'pending' || status == 'resubmitted' || status == 'needs_review';
                    }).toList()
                      ..sort((a, b) {
                        final aTs = a.data()['approval_requested_at'] as Timestamp? ?? a.data()['created_at'] as Timestamp?;
                        final bTs = b.data()['approval_requested_at'] as Timestamp? ?? b.data()['created_at'] as Timestamp?;
                        final aDate = aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                        final bDate = bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                        return aDate.compareTo(bDate);
                      });

                    if (pending.isEmpty) {
                      return _emptyState(theme);
                    }

                    return ListView.separated(
                      controller: _approvalsScrollController,
                      itemCount: pending.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final doc = pending[index];
                        final data = doc.data();
                        return _PendingTherapistCard(
                          data: data,
                          onApprove: () => _approveTherapist(doc.id),
                          onViewDetails: () => _showTherapistDetails(data),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return AppDrawer(
      title: 'Admin',
      subtitle: 'Manage platform operations and settings.',
      children: [
        ListTile(
          leading: Icon(Icons.dashboard_customize_outlined, color: primary),
          title: const Text('Dashboard overview'),
          subtitle: const Text('Review live platform metrics.'),
          onTap: () {
            Navigator.of(context).pop();
          },
        ),
        ListTile(
          leading: Icon(Icons.verified_user_outlined, color: primary),
          title: const Text('Therapist approvals'),
          subtitle: const Text('Review pending clinician submissions.'),
          onTap: _scrollToApprovalsSection,
        ),
        ListTile(
          leading: Icon(Icons.settings_suggest_outlined, color: primary),
          title: const Text('Admin settings'),
          subtitle: const Text('Configure OpenAI & SendGrid.'),
          onTap: () {
            Navigator.of(context).pop();
            Future.microtask(() {
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminSettingsPage()),
              );
            });
          },
        ),
        ListTile(
          leading: Icon(Icons.logout, color: primary),
          title: const Text('Sign out'),
          onTap: () async {
            Navigator.of(context).pop();
            await FirebaseAuthManager().signOut();
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthWelcomePage(initialTab: AuthTab.login)),
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  void _scrollToApprovalsSection() {
    Navigator.of(context).pop();
    Future.microtask(() {
      if (!mounted) return;
      if (_approvalsScrollController.hasClients) {
        _approvalsScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Widget _buildMetricsRow(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final cards = [
      _MetricCard(
        title: 'Therapist ↔ Patient conversations',
        value: _loadingCounts ? null : _humanConversationCount,
        icon: Icons.forum_outlined,
        accentColor: colorScheme.primary,
        error: _countsError,
      ),
      _MetricCard(
        title: 'Patient ↔ AI conversations',
        value: _loadingCounts ? null : _aiConversationCount,
        icon: Icons.smart_toy_outlined,
        accentColor: colorScheme.secondary,
        error: _countsError,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 12),
              ],
            ],
          );
        }
        return Row(
          children: cards
              .map((card) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: card)))
              .toList(),
        );
      },
    );
  }

  Widget _errorState(ThemeData theme, String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('No pending approvals', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Therapists will appear here once they submit their credentials. You can leave this page open to review in real-time.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatLocation(Map<String, dynamic> data) {
    final city = (data['city'] ?? '').toString().trim();
    final state = (data['state'] ?? '').toString().trim();
    final zip = (data['zip_code'] ?? '').toString().trim();
    return [city, state, zip].where((part) => part.isNotEmpty).join(', ');
  }

  static List<String> _resolveEducationSummaries(Map<String, dynamic> data) {
    final entries = <String>{};
    final rawEntries = data['education_entries'];
    if (rawEntries is Iterable) {
      for (final item in rawEntries) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item as Map);
          final summary = _formatEducationMap(map);
          if (summary.trim().isNotEmpty) entries.add(summary);
        }
      }
    }
    final legacy = data['educations'];
    if (legacy is Iterable) {
      for (final item in legacy) {
        if (item is String && item.trim().isNotEmpty) {
          entries.add(item.trim());
        }
      }
    }
    return entries.toList();
  }

  static String _formatEducationMap(Map<String, dynamic> map) {
    final qualification = (map['qualification'] ?? '').toString().trim();
    final institution = (map['institution'] ?? map['university'] ?? '').toString().trim();
    final year = map['year_completed']?.toString().trim();
    final parts = [
      if (qualification.isNotEmpty) qualification,
      if (institution.isNotEmpty) institution,
      if (year != null && year.isNotEmpty) 'Completed $year',
    ];
    return parts.join(' • ');
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final int? value;
  final IconData icon;
  final Color accentColor;
  final String? error;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = error != null;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: accentColor.withOpacity(0.12),
              child: Icon(icon, color: accentColor),
            ),
            const SizedBox(height: 16),
            Text(
              hasError ? '—' : (value?.toString() ?? '—'),
              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingTherapistCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onApprove;
  final VoidCallback onViewDetails;

  const _PendingTherapistCard({
    required this.data,
    required this.onApprove,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = (data['full_name'] ?? 'Unnamed therapist').toString();
    final practice = (data['practice_name'] ?? '—').toString();
    final approvalRequestedAt = data['approval_requested_at'] as Timestamp? ?? data['created_at'] as Timestamp?;
    final requestedLabel = approvalRequestedAt != null
        ? 'Requested ${_timeAgo(approvalRequestedAt.toDate())}'
        : 'Awaiting review';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(practice, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
                      const SizedBox(height: 4),
                      Text(requestedLabel, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.verified),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InfoPill(icon: Icons.location_on_outlined, label: _AdminDashboardPageState._formatLocation(data)),
                if ((data['contact_email'] ?? '').toString().isNotEmpty)
                  _InfoPill(icon: Icons.email_outlined, label: data['contact_email']),
                if ((data['contact_phone'] ?? '').toString().isNotEmpty)
                  _InfoPill(icon: Icons.phone_outlined, label: data['contact_phone']),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.remove_red_eye_outlined),
                label: const Text('View full submission'),
                style: TextButton.styleFrom(foregroundColor: colorScheme.primary, textStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _timeAgo(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inDays < 1) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    return '${time.month}/${time.day}/${time.year}';
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}