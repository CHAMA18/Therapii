import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TherapistApprovalsPage extends StatefulWidget {
  const TherapistApprovalsPage({super.key});

  @override
  State<TherapistApprovalsPage> createState() => _TherapistApprovalsPageState();
}

class _TherapistApprovalsPageState extends State<TherapistApprovalsPage> with SingleTickerProviderStateMixin {
  late final FirebaseFirestore _firestore;
  late final TabController _tabController;
  String _filter = 'all';
  final List<String> _filters = ['all', 'pending', 'approved', 'rejected'];

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _filter = _filters[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _approveTherapist(String therapistId) async {
    try {
      await _firestore.collection('therapists').doc(therapistId).set({
        'approval_status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _showSuccessSnackbar('Therapist approved successfully');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar('Failed to approve therapist');
    }
  }

  Future<void> _rejectTherapist(String therapistId) async {
    try {
      await _firestore.collection('therapists').doc(therapistId).set({
        'approval_status': 'rejected',
        'rejected_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _showSuccessSnackbar('Application rejected');
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackbar('Failed to reject therapist');
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: const Color(0xFF22C55E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showTherapistDetails(Map<String, dynamic> data, String? status) {
    final educations = _resolveEducationSummaries(data);
    final licensure = List<String>.from(data['state_licensures'] ?? const <String>[]);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with avatar and name
                      Row(
                        children: [
                          _buildDetailAvatar(data, status, 56),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['full_name'] ?? 'Therapist',
                                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['practice_name'] ?? 'Independent Practice',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _DetailStatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Contact Information Section
                      _DetailSection(
                        title: 'Contact Information',
                        icon: Icons.contact_mail_outlined,
                        children: [
                          _DetailInfoTile(
                            icon: Icons.location_on_outlined,
                            label: 'Location',
                            value: _formatLocation(data),
                          ),
                          _DetailInfoTile(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: data['contact_email'] ?? 'Not provided',
                          ),
                          _DetailInfoTile(
                            icon: Icons.phone_outlined,
                            label: 'Phone',
                            value: data['contact_phone'] ?? 'Not provided',
                          ),
                        ],
                      ),

                      if (licensure.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _DetailSection(
                          title: 'State Licensure',
                          icon: Icons.verified_outlined,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: licensure.map((item) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  item,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ],
                        ),
                      ],

                      if (educations.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _DetailSection(
                          title: 'Education',
                          icon: Icons.school_outlined,
                          children: educations.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(entry, style: theme.textTheme.bodyMedium),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ],

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailAvatar(Map<String, dynamic> data, String? status, double size) {
    final name = (data['full_name'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = _getStatusColor(status);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: color,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _refreshData() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Therapist Approvals',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Stats Cards
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('therapists').snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final pending = docs.where((d) {
                  final s = (d.data()['approval_status'] as String?)?.toLowerCase();
                  return s == null || s == 'pending' || s == 'resubmitted' || s == 'needs_review';
                }).length;
                final approved = docs.where((d) => (d.data()['approval_status'] as String?)?.toLowerCase() == 'approved').length;
                final rejected = docs.where((d) => (d.data()['approval_status'] as String?)?.toLowerCase() == 'rejected').length;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _StatCard(count: pending, label: 'Pending', color: const Color(0xFFF59E0B), icon: Icons.schedule)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(count: approved, label: 'Approved', color: const Color(0xFF22C55E), icon: Icons.check_circle_outline)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(count: rejected, label: 'Rejected', color: const Color(0xFFEF4444), icon: Icons.cancel_outlined)),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Premium Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: colorScheme.onSurface,
                  unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.5),
                  labelStyle: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                  unselectedLabelStyle: theme.textTheme.labelMedium,
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Pending'),
                    Tab(text: 'Approved'),
                    Tab(text: 'Rejected'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Content
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore.collection('therapists').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _errorState(theme, 'Unable to load therapist submissions');
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final filtered = docs.where((doc) {
                    final status = (doc.data()['approval_status'] as String?)?.toLowerCase();
                    if (_filter == 'all') return true;
                    if (_filter == 'pending') {
                      return status == null || status == 'pending' || status == 'resubmitted' || status == 'needs_review';
                    }
                    return status == _filter;
                  }).toList()
                    ..sort((a, b) {
                      final aTs = a.data()['approval_requested_at'] as Timestamp? ?? a.data()['created_at'] as Timestamp?;
                      final bTs = b.data()['approval_requested_at'] as Timestamp? ?? b.data()['created_at'] as Timestamp?;
                      final aDate = aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                      final bDate = bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                      return bDate.compareTo(aDate);
                    });

                  if (filtered.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refreshData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: _emptyState(theme),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshData,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data();
                        final status = (data['approval_status'] as String?)?.toLowerCase();
                        final isPending = status == null || status == 'pending' || status == 'resubmitted' || status == 'needs_review';
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 300 + (index * 50)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: isPending
                                ? _PendingApprovalCard(
                                    data: data,
                                    status: status,
                                    onApprove: () => _approveTherapist(doc.id),
                                    onReject: () => _rejectTherapist(doc.id),
                                    onViewDetails: () => _showTherapistDetails(data, status),
                                  )
                                : _TherapistCard(
                                    data: data,
                                    status: status,
                                    onApprove: status == 'approved' ? null : () => _approveTherapist(doc.id),
                                    onReject: status == 'rejected' ? null : () => _rejectTherapist(doc.id),
                                    onViewDetails: () => _showTherapistDetails(data, status),
                                  ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    final messages = {
      'all': ('No applications yet', 'New therapist applications will appear here'),
      'pending': ('No pending applications', 'All caught up! No applications waiting for review'),
      'approved': ('No approved therapists', 'Approved therapists will appear here'),
      'rejected': ('No rejected applications', 'Rejected applications will appear here'),
    };
    final (title, subtitle) = messages[_filter] ?? messages['all']!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _filter == 'pending' ? Icons.check_circle_outline : Icons.inbox_outlined,
                size: 56,
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
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
    final parts = [city, state, zip].where((part) => part.isNotEmpty);
    return parts.isEmpty ? 'Unknown location' : parts.join(', ');
  }

  static Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF22C55E);
      case 'rejected':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
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

// Stats Card Widget
class _StatCard extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _StatCard({required this.count, required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

// Premium Pending Approval Card
class _PendingApprovalCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String? status;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewDetails;

  const _PendingApprovalCard({
    required this.data,
    required this.status,
    required this.onApprove,
    required this.onReject,
    required this.onViewDetails,
  });

  @override
  State<_PendingApprovalCard> createState() => _PendingApprovalCardState();
}

class _PendingApprovalCardState extends State<_PendingApprovalCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = (widget.data['full_name'] ?? 'Unnamed Therapist').toString();
    final practice = (widget.data['practice_name'] ?? '').toString();
    final email = (widget.data['contact_email'] ?? '').toString();
    final phone = (widget.data['contact_phone'] ?? '').toString();
    final location = _TherapistApprovalsPageState._formatLocation(widget.data);
    final licensure = List<String>.from(widget.data['state_licensures'] ?? const <String>[]);
    final specializations = List<String>.from(widget.data['specializations'] ?? const <String>[]);

    final approvalRequestedAt = widget.data['approval_requested_at'] as Timestamp? ?? widget.data['created_at'] as Timestamp?;
    final waitingDays = approvalRequestedAt != null
        ? DateTime.now().difference(approvalRequestedAt.toDate()).inDays
        : 0;
    final dateLabel = approvalRequestedAt != null ? _formatDate(approvalRequestedAt.toDate()) : 'Unknown date';

    final amberColor = const Color(0xFFF59E0B);
    final isResubmitted = widget.status == 'resubmitted';
    final isNeedsReview = widget.status == 'needs_review';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isHovered ? 1.01 : 1.0),
        child: Stack(
          children: [
            // Animated glow border for pending items
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: amberColor.withValues(alpha: _pulseAnimation.value * 0.3),
                        blurRadius: 20,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Main card
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surface,
                    amberColor.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: amberColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Priority header banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          amberColor.withValues(alpha: 0.15),
                          amberColor.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: amberColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isResubmitted ? Icons.refresh : isNeedsReview ? Icons.rate_review_outlined : Icons.hourglass_top,
                            color: amberColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isResubmitted ? 'Resubmitted Application' : isNeedsReview ? 'Needs Review' : 'Awaiting Review',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: amberColor,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Text(
                                'Submitted $dateLabel${waitingDays > 0 ? ' • $waitingDays day${waitingDays > 1 ? 's' : ''} ago' : ''}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (waitingDays >= 3)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.priority_high, size: 14, color: const Color(0xFFEF4444)),
                                const SizedBox(width: 4),
                                Text(
                                  'Urgent',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFFEF4444),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Main content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile section
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Premium avatar with gradient ring
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [amberColor, amberColor.withValues(alpha: 0.5)],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      color: amberColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (practice.isNotEmpty) ...[                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.business_outlined, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            practice,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: colorScheme.onSurface.withValues(alpha: 0.7),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (location.isNotEmpty && location != 'Unknown location') ...[                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on_outlined, size: 14, color: colorScheme.primary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            location,
                                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Quick info chips
                        if (licensure.isNotEmpty || specializations.isNotEmpty) ...[                          _QuickInfoSection(licensure: licensure, specializations: specializations),
                          const SizedBox(height: 16),
                        ],
                        // Contact grid
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              if (email.isNotEmpty)
                                Expanded(
                                  child: _PendingContactItem(
                                    icon: Icons.email_outlined,
                                    value: email,
                                    label: 'Email',
                                  ),
                                ),
                              if (email.isNotEmpty && phone.isNotEmpty)
                                Container(
                                  width: 1,
                                  height: 36,
                                  margin: const EdgeInsets.symmetric(horizontal: 12),
                                  color: colorScheme.outline.withValues(alpha: 0.15),
                                ),
                              if (phone.isNotEmpty)
                                Expanded(
                                  child: _PendingContactItem(
                                    icon: Icons.phone_outlined,
                                    value: phone,
                                    label: 'Phone',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Premium action bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
                    ),
                    child: Row(
                      children: [
                        // View Details button
                        Expanded(
                          child: _PremiumActionButton(
                            icon: Icons.visibility_outlined,
                            label: 'View Details',
                            onPressed: widget.onViewDetails,
                            style: _ActionButtonStyle.neutral,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Reject button
                        Expanded(
                          child: _PremiumActionButton(
                            icon: Icons.close_rounded,
                            label: 'Reject',
                            onPressed: widget.onReject,
                            style: _ActionButtonStyle.danger,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Approve button (primary CTA)
                        Expanded(
                          flex: 2,
                          child: _PremiumActionButton(
                            icon: Icons.check_rounded,
                            label: 'Approve',
                            onPressed: widget.onApprove,
                            style: _ActionButtonStyle.success,
                            isPrimary: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// Quick Info Section
class _QuickInfoSection extends StatelessWidget {
  final List<String> licensure;
  final List<String> specializations;

  const _QuickInfoSection({required this.licensure, required this.specializations});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayItems = <(String, IconData, Color)>[];
    
    for (final license in licensure.take(3)) {
      displayItems.add((license, Icons.verified_outlined, const Color(0xFF3B82F6)));
    }
    for (final spec in specializations.take(2)) {
      displayItems.add((spec, Icons.psychology_outlined, const Color(0xFF8B5CF6)));
    }

    if (displayItems.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: displayItems.map((item) {
        final (label, icon, color) = item;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// Pending Contact Item
class _PendingContactItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _PendingContactItem({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// Action Button Style
enum _ActionButtonStyle { neutral, danger, success }

// Premium Action Button
class _PremiumActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final _ActionButtonStyle style;
  final bool isPrimary;

  const _PremiumActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.style,
    this.isPrimary = false,
  });

  @override
  State<_PremiumActionButton> createState() => _PremiumActionButtonState();
}

class _PremiumActionButtonState extends State<_PremiumActionButton> {
  bool _isPressed = false;

  Color get _color => switch (widget.style) {
    _ActionButtonStyle.neutral => Theme.of(context).colorScheme.primary,
    _ActionButtonStyle.danger => const Color(0xFFEF4444),
    _ActionButtonStyle.success => const Color(0xFF22C55E),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: widget.isPrimary ? _color : _color.withValues(alpha: _isPressed ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: widget.isPrimary ? null : Border.all(color: _color.withValues(alpha: 0.2)),
          boxShadow: widget.isPrimary
              ? [
                  BoxShadow(
                    color: _color.withValues(alpha: _isPressed ? 0.2 : 0.3),
                    blurRadius: _isPressed ? 4 : 8,
                    offset: Offset(0, _isPressed ? 2 : 4),
                  ),
                ]
              : null,
        ),
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: 18,
              color: widget.isPrimary ? Colors.white : _color,
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: widget.isPrimary ? Colors.white : _color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Therapist Card Widget
class _TherapistCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String? status;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback onViewDetails;

  const _TherapistCard({
    required this.data,
    required this.status,
    required this.onApprove,
    required this.onReject,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = (data['full_name'] ?? 'Unnamed Therapist').toString();
    final practice = (data['practice_name'] ?? '').toString();
    final email = (data['contact_email'] ?? '').toString();
    final phone = (data['contact_phone'] ?? '').toString();
    final location = _TherapistApprovalsPageState._formatLocation(data);

    final approvalRequestedAt = data['approval_requested_at'] as Timestamp? ?? data['created_at'] as Timestamp?;
    final dateLabel = approvalRequestedAt != null
        ? _formatDate(approvalRequestedAt.toDate())
        : 'Unknown date';

    final statusColor = _TherapistApprovalsPageState._getStatusColor(status);

    return GestureDetector(
      onTap: onViewDetails,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Main Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [statusColor.withValues(alpha: 0.2), statusColor.withValues(alpha: 0.08)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Name and Practice
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (practice.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                practice,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 12, color: colorScheme.primary),
                                const SizedBox(width: 4),
                                Text(
                                  dateLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                                ),
                                const SizedBox(width: 12),
                                _CardStatusBadge(status: status),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Container(height: 1, color: colorScheme.outline.withValues(alpha: 0.08)),
                  const SizedBox(height: 16),

                  // Contact Info
                  Row(
                    children: [
                      Expanded(
                        child: _ContactPill(icon: Icons.location_on_outlined, text: location),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (email.isNotEmpty)
                        Expanded(child: _ContactPill(icon: Icons.email_outlined, text: email)),
                      if (email.isNotEmpty && phone.isNotEmpty) const SizedBox(width: 10),
                      if (phone.isNotEmpty)
                        Expanded(child: _ContactPill(icon: Icons.phone_outlined, text: phone)),
                    ],
                  ),
                ],
              ),
            ),

            // Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  // View Details
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onViewDetails,
                      icon: Icon(Icons.visibility_outlined, size: 18, color: colorScheme.primary),
                      label: Text('Details', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  if (onReject != null || onApprove != null) ...[
                    Container(width: 1, height: 32, color: colorScheme.outline.withValues(alpha: 0.15)),
                    // Reject Button
                    if (onReject != null)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.close, size: 18, color: Color(0xFFEF4444)),
                          label: const Text('Reject', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    if (onApprove != null) ...[
                      Container(width: 1, height: 32, color: colorScheme.outline.withValues(alpha: 0.15)),
                      // Approve Button
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onApprove,
                          icon: const Icon(Icons.check, size: 18, color: Color(0xFF22C55E)),
                          label: const Text('Approve', style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.w600)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

// Contact Pill Widget
class _ContactPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Card Status Badge
class _CardStatusBadge extends StatelessWidget {
  final String? status;

  const _CardStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color, bgColor) = _getStatusStyle();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  (String, Color, Color) _getStatusStyle() {
    switch (status) {
      case 'approved':
        return ('Approved', const Color(0xFF22C55E), const Color(0xFF22C55E).withValues(alpha: 0.12));
      case 'rejected':
        return ('Rejected', const Color(0xFFEF4444), const Color(0xFFEF4444).withValues(alpha: 0.12));
      case 'resubmitted':
        return ('Resubmitted', const Color(0xFFF59E0B), const Color(0xFFF59E0B).withValues(alpha: 0.12));
      case 'needs_review':
        return ('Needs Review', const Color(0xFFF59E0B), const Color(0xFFF59E0B).withValues(alpha: 0.12));
      default:
        return ('Pending', const Color(0xFFF59E0B), const Color(0xFFF59E0B).withValues(alpha: 0.12));
    }
  }
}

// Detail Status Badge for Modal
class _DetailStatusBadge extends StatelessWidget {
  final String? status;

  const _DetailStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _TherapistApprovalsPageState._getStatusColor(status);
    final label = status == 'approved' ? 'Approved' : status == 'rejected' ? 'Rejected' : 'Pending';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// Detail Section Widget
class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DetailSection({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

// Detail Info Tile Widget
class _DetailInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailInfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
