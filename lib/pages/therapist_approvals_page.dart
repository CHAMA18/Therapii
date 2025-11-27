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
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
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

  Future<void> _refreshData() async {
    // The StreamBuilder already listens to real-time updates
    // This just provides visual feedback
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Therapist Approvals', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _buildCustomSegmentedControl(theme),
          ),
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
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: _emptyState(theme),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
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
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomSegmentedControl(ThemeData theme) {
    // A custom look to match the screenshot more closely than SegmentedButton
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _buildSegment('All', 'all'),
          _buildSegment('Pending', 'pending'),
          _buildSegment('Approved', 'approved'),
          _buildSegment('Rejected', 'rejected'),
        ],
      ),
    );
  }

  Widget _buildSegment(String label, String value) {
    final isSelected = _filter == value;
    final theme = Theme.of(context);
    
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5E6A81) : Colors.transparent, // Dark grey/blueish from screenshot
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                const Icon(Icons.check, size: 16, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text('No applications found', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Try changing the filter or come back later.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
    final name = (data['full_name'] ?? 'Unnamed Therapist').toString();
    final practice = (data['practice_name'] ?? 'No Practice Name').toString();
    final email = (data['contact_email'] ?? '').toString();
    final phone = (data['contact_phone'] ?? '').toString();
    final location = _TherapistApprovalsPageState._formatLocation(data);
    
    final approvalRequestedAt = data['approval_requested_at'] as Timestamp? ?? data['created_at'] as Timestamp?;
    final dateLabel = approvalRequestedAt != null
        ? '${approvalRequestedAt.toDate().month}/${approvalRequestedAt.toDate().day}/${approvalRequestedAt.toDate().year}'
        : 'Unknown Date';

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _getStatusColor(colorScheme).withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: theme.textTheme.headlineSmall?.copyWith(
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
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        practice,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Requested $dateLabel',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF1976D2), // Blue link color from screenshot
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _StatusBadge(status: status),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Location
            _IconTextRow(
              icon: Icons.location_on_outlined,
              text: location,
            ),
            
            const SizedBox(height: 12),
            
            // Email & Phone
            Row(
              children: [
                Expanded(
                  child: _IconTextRow(
                    icon: Icons.email_outlined,
                    text: email,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: _IconTextRow(
                      icon: Icons.phone_outlined,
                      text: phone,
                    ),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 12,
              children: [
                TextButton.icon(
                  onPressed: onViewDetails,
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
                  label: const Text('View details'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1976D2),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (onReject != null)
                      OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    if (onApprove != null)
                      FilledButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.verified, size: 18),
                        label: const Text('Approve'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
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
        return const Color(0xFF1976D2);
    }
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
    final color = _getStatusColor(colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        statusText,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
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
        return const Color(0xFF4CAF50); // Green
      case 'rejected':
        return colorScheme.error;
      default:
        return const Color(0xFF1976D2); // Blue
    }
  }
}

class _IconTextRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconTextRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = text.trim().isNotEmpty;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        if (hasText) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
