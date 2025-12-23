import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/pages/admin_ai_chats_page.dart';
import 'package:therapii/pages/admin_sessions_page.dart';
import 'package:therapii/pages/admin_settings_page.dart';
import 'package:therapii/pages/auth_welcome_page.dart';
import 'package:therapii/pages/therapist_approvals_page.dart';
import 'package:therapii/utils/admin_access.dart';
import 'package:therapii/widgets/app_drawer.dart';
import 'package:therapii/widgets/dashboard_action_card.dart';

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: theme.colorScheme.surface,
      builder: (sheetContext) {
        final padding = EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 32,
          top: 32,
        );
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['full_name'] ?? 'Therapist details',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['practice_name'] ?? 'Private Practice',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(title: 'Contact Information'),
                        const SizedBox(height: 12),
                        _DetailItem(
                          icon: Icons.location_on_outlined,
                          label: 'Location',
                          value: _formatLocation(data),
                        ),
                        _DetailItem(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: data['contact_email'],
                        ),
                        _DetailItem(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: data['contact_phone'],
                        ),
                        const SizedBox(height: 24),
                        if (licensure.isNotEmpty) ...[
                          _SectionHeader(title: 'State Licensure'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: licensure
                                .map((item) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: theme.colorScheme.primaryContainer,
                                        ),
                                      ),
                                      child: Text(
                                        item,
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (educations.isNotEmpty) ...[
                          _SectionHeader(title: 'Education'),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final entry in educations)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6, right: 12),
                                        child: Icon(
                                          Icons.school_outlined,
                                          size: 18,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          entry,
                                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String greeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good morning';
      if (hour < 17) return 'Good afternoon';
      return 'Good evening';
    }

    // Display name for admin (fallback to email prefix)
    String adminName() {
      final user = _auth.currentUser;
      final email = user?.email ?? '';
      if (email.contains('@')) return email.split('@').first;
      return 'Admin';
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Dashboard'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: _loadCounts,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header (mirrors patient dashboard style)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 36),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 620),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${greeting()},',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Text(
                                adminName(),
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Manage approvals, monitor activity, and configure the platform.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              (adminName().isNotEmpty ? adminName()[0].toUpperCase() : 'A'),
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Cards Grid (mirrors patient style)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final isWide = width > 600;

                      if (!isWide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DashboardActionCard(
                              title: 'Therapist Approvals',
                              subtitle: 'Review and approve new clinicians',
                              icon: Icons.verified_user_outlined,
                              isPrimary: true,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const TherapistApprovalsPage()),
                              ),
                            ),
                            const SizedBox(height: 20),
                            DashboardActionCard(
                              title: 'Admin Settings',
                              subtitle: 'OpenAI, SendGrid and platform keys',
                              icon: Icons.settings_suggest_outlined,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AdminSettingsPage()),
                              ),
                            ),
                            const SizedBox(height: 20),
                            DashboardActionCard(
                              title: 'Sessions',
                              subtitle: _loadingCounts
                                  ? 'Loading...'
                                  : '$_humanConversationCount total sessions',
                              icon: Icons.forum_outlined,
                              isSecondary: true,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AdminSessionsPage()),
                              ),
                            ),
                            const SizedBox(height: 20),
                            DashboardActionCard(
                              title: 'AI Chats',
                              subtitle: _loadingCounts
                                  ? 'Loading...'
                                  : '$_aiConversationCount assistant chats',
                              icon: Icons.smart_toy_outlined,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const AdminAiChatsPage()),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Therapist Approvals',
                                  subtitle: 'Review and approve new clinicians',
                                  icon: Icons.verified_user_outlined,
                                  isPrimary: true,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const TherapistApprovalsPage()),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Admin Settings',
                                  subtitle: 'OpenAI, SendGrid and platform keys',
                                  icon: Icons.settings_suggest_outlined,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const AdminSettingsPage()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Sessions',
                                  subtitle: _loadingCounts
                                      ? 'Loading...'
                                      : '$_humanConversationCount total sessions',
                                  icon: Icons.forum_outlined,
                                  isSecondary: true,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const AdminSessionsPage()),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'AI Chats',
                                  subtitle:
                                      _loadingCounts ? 'Loading...' : '$_aiConversationCount assistant chats',
                                  icon: Icons.smart_toy_outlined,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const AdminAiChatsPage()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 48),

                  // Pending approvals list styled like patient lists
                  _buildPendingApprovalsSection(theme),

                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const TherapistApprovalsPage()),
                        );
                      },
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('Manage'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Removed old gradient header in favor of patient-style header

  Widget _buildPendingApprovalsSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Use surface color but maybe with elevation/shadow to stand out if background is off-white
        // Or actually, let's give it a slight background color container like the "Active patients" card in screenshot which seems to be white on a very light grey background
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.08)),
        // No shadow to match clean look or slight shadow
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pending Approvals',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List of pending approvals
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('therapists').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: _errorState(theme, 'Unable to load therapist submissions. ${snapshot.error}'),
                );
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
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Text(
                        'No pending approvals',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Great job! You\'re all caught up.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Show only top 5 pending
              final displayList = pending.take(5).toList();

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayList.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 20, endIndent: 20),
                itemBuilder: (context, index) {
                  final doc = displayList[index];
                  final data = doc.data();
                  return _PendingListItem(
                    data: data,
                    onTap: () => _showTherapistDetails(data),
                    onApprove: () => _approveTherapist(doc.id),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
        ],
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
    // No-op for now as we don't have easy scrolling to the specific section in custom scroll view without key
  }

  Widget _errorState(ThemeData theme, String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.errorContainer),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
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
          final map = Map<String, dynamic>.from(item);
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

class _HeaderMetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderMetricPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingListItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onApprove;

  const _PendingListItem({
    required this.data,
    required this.onTap,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (data['full_name'] ?? 'Unnamed therapist').toString();
    final practice = (data['practice_name'] ?? '—').toString();
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      onTap: onTap,
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        practice,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton.filled(
        onPressed: onApprove,
        icon: const Icon(Icons.check, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
        ),
        tooltip: 'Approve',
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
