import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TherapistApprovalsPage extends StatefulWidget {
  const TherapistApprovalsPage({super.key});

  @override
  State<TherapistApprovalsPage> createState() => _TherapistApprovalsPageState();
}

class _TherapistApprovalsPageState extends State<TherapistApprovalsPage> {
  late final FirebaseFirestore _firestore;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _firestore = FirebaseFirestore.instance;
  }

  Future<void> _approveTherapist(String therapistId) async {
    try {
      await _firestore.collection('therapists').doc(therapistId).set({
        'approval_status': 'approved',
        'approved_at': FieldValue.serverTimestamp(),
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

  Future<void> _rejectTherapist(String therapistId) async {
    try {
      await _firestore.collection('therapists').doc(therapistId).set({
        'approval_status': 'rejected',
        'rejected_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapist application rejected.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject therapist. $e')),
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
                _detailRow('Practice', data['practice_name'], theme),
                _detailRow('Location', _formatLocation(data), theme),
                _detailRow('Email', data['contact_email'], theme),
                _detailRow('Phone', data['contact_phone'], theme),
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

  Widget _detailRow(String label, dynamic value, ThemeData theme) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return const SizedBox.shrink();
    }
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
        title: const Text('Therapist Approvals'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final showLabels = constraints.maxWidth > 400;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'all',
                        label: Text('All'),
                        icon: showLabels ? const Icon(Icons.list) : null,
                      ),
                      ButtonSegment(
                        value: 'pending',
                        label: Text('Pending'),
                        icon: showLabels ? const Icon(Icons.pending_actions) : null,
                      ),
                      ButtonSegment(
                        value: 'approved',
                        label: Text('Approved'),
                        icon: showLabels ? const Icon(Icons.check_circle) : null,
                      ),
                      ButtonSegment(
                        value: 'rejected',
                        label: Text('Rejected'),
                        icon: showLabels ? const Icon(Icons.cancel) : null,
                      ),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (Set<String> selection) {
                      setState(() => _filter = selection.first);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
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
              return _emptyState(theme);
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final doc = filtered[index];
                final data = doc.data();
                final status = (data['approval_status'] as String?)?.toLowerCase();
                return _TherapistCard(
                  data: data,
                  status: status,
                  onApprove: status == 'approved' ? null : () => _approveTherapist(doc.id),
                  onReject: status == 'rejected' ? null : () => _rejectTherapist(doc.id),
                  onViewDetails: () => _showTherapistDetails(data),
                );
              },
            );
          },
        ),
      ),
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
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('No therapist applications', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Therapist submissions matching your filter will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
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
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 6)),
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
                  backgroundColor: _getStatusColor(colorScheme).withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: _getStatusColor(colorScheme),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(practice, style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              requestedLabel,
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.primary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(status: status),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InfoPill(icon: Icons.location_on_outlined, label: _TherapistApprovalsPageState._formatLocation(data)),
                if ((data['contact_email'] ?? '').toString().isNotEmpty)
                  _InfoPill(icon: Icons.email_outlined, label: data['contact_email']),
                if ((data['contact_phone'] ?? '').toString().isNotEmpty)
                  _InfoPill(icon: Icons.phone_outlined, label: data['contact_phone']),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: onViewDetails,
                  icon: const Icon(Icons.remove_red_eye_outlined),
                  label: const Text('View details'),
                  style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onReject != null)
                      OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.cancel),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
                      ),
                    if (onApprove != null) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.verified),
                        label: const Text('Approve'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ColorScheme colorScheme) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return colorScheme.error;
      default:
        return colorScheme.primary;
    }
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

class _StatusBadge extends StatelessWidget {
  final String? status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusText = _getStatusText();
    final statusColor = _getStatusColor(colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        statusText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'resubmitted':
        return 'Resubmitted';
      case 'needs_review':
        return 'Needs Review';
      default:
        return 'Pending';
    }
  }

  Color _getStatusColor(ColorScheme colorScheme) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return colorScheme.error;
      default:
        return colorScheme.primary;
    }
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
