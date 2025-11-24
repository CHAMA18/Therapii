import 'package:flutter/material.dart';

/// Decorative gate used to hold therapists inside onboarding while their
/// credentials are pending administrative review.
class TherapistApprovalGate extends StatelessWidget {
  final String status;
  final DateTime? requestedAt;
  final VoidCallback onRefresh;
  final VoidCallback onUpdateProfile;
  final Future<void> Function()? onSignOut;
  final bool refreshing;
  final bool signingOut;
  final String title;
  final String subtitle;

  const TherapistApprovalGate({
    super.key,
    required this.status,
    required this.onRefresh,
    required this.onUpdateProfile,
    this.onSignOut,
    this.requestedAt,
    this.refreshing = false,
    this.signingOut = false,
    this.title = 'Your application is under review',
    this.subtitle =
        'Thanks for sharing your background. Our clinical team is verifying your credentials to keep Therapii safe and trusted for every patient.',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedStatus = status.trim().toLowerCase();
    final highlight = _statusHighlight(theme, normalizedStatus);
    final statusLabel = highlight.label;
    final badgeColor = highlight.color;
    final statusIcon = highlight.icon;
    final statusDescription = highlight.description;
    final requestLabel = _requestedLabel(requestedAt);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.75),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.28),
                      blurRadius: 32,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: theme.colorScheme.onPrimary.withOpacity(0.12),
                        child: Icon(Icons.verified_user_outlined, size: 32, color: theme.colorScheme.onPrimary),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onPrimary.withOpacity(0.78),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 18, color: badgeColor),
                                const SizedBox(width: 8),
                                Text(
                                  statusLabel,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: badgeColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Flexible(
                            child: Text(
                              requestLabel,
                              textAlign: TextAlign.right,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        statusDescription,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.75),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _BenefitRow(
                        icon: Icons.shield_moon_outlined,
                        label: 'Credential verification',
                        description: 'Our clinical reviewers confirm your licensure and education to protect the community.',
                      ),
                      const SizedBox(height: 16),
                      _BenefitRow(
                        icon: Icons.timer_outlined,
                        label: 'Typical timeline',
                        description: 'Most approvals are completed within one business day. You will receive an email once approved.',
                      ),
                      const SizedBox(height: 16),
                      _BenefitRow(
                        icon: Icons.mail_outlined,
                        label: 'Need to update details?',
                        description: 'You can revisit your profile to adjust any licensure or education information if requested.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: refreshing ? null : onRefresh,
                icon: refreshing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: Text(refreshing ? 'Checking status…' : 'Check status again'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: refreshing ? null : onUpdateProfile,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Update therapist profile'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (onSignOut != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: (refreshing || signingOut) ? null : () async {
                    await onSignOut!.call();
                  },
                  icon: signingOut
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(signingOut ? 'Signing out…' : 'Sign out'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: theme.colorScheme.onSurfaceVariant,
                    textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _ApprovalHighlight _statusHighlight(ThemeData theme, String status) {
    switch (status) {
      case 'approved':
        return _ApprovalHighlight(
          label: 'Approved',
          description: 'Your profile is live. You now have full access to your dashboard and patient tools.',
          color: theme.colorScheme.secondary,
          icon: Icons.verified,
        );
      case 'needs_review':
      case 'resubmitted':
        return _ApprovalHighlight(
          label: 'Additional info requested',
          description: 'We asked for a quick update. Update your details so we can finish the review.',
          color: theme.colorScheme.tertiary,
          icon: Icons.info_outline,
        );
      case 'pending':
      default:
        return _ApprovalHighlight(
          label: 'Pending review',
          description: 'Our admin team is reviewing your submission. We will notify you as soon as it is approved.',
          color: theme.colorScheme.primary,
          icon: Icons.hourglass_bottom,
        );
    }
  }

  String _requestedLabel(DateTime? time) {
    if (time == null) {
      return 'Awaiting submission';
    }
    final months = const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[time.month - 1];
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final meridiem = time.hour >= 12 ? 'PM' : 'AM';
    return 'Submitted $month ${time.day}, ${time.year} • $hour:$minute $meridiem';
  }
}

class _ApprovalHighlight {
  final String label;
  final String description;
  final Color color;
  final IconData icon;

  const _ApprovalHighlight({
    required this.label,
    required this.description,
    required this.color,
    required this.icon,
  });
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;

  const _BenefitRow({
    required this.icon,
    required this.label,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colorScheme.primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.72),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}