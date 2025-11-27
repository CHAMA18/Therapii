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
    
    // Use a lighter blue gradient for the background to look "world-class"
    // and match the reference style of clean, trustworthy medical apps.
    final primaryColor = theme.colorScheme.primary;
    final topGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primaryColor,
        Color.lerp(primaryColor, Colors.white, 0.2)!,
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Blue header background
            Container(
              height: 340,
              decoration: BoxDecoration(
                gradient: topGradient,
              ),
            ),
            
            // Content
            SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Text
                      Text(
                        title,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Status Card
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top row with Badge and Date
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: highlight.color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(highlight.icon, size: 18, color: highlight.color),
                                        const SizedBox(width: 8),
                                        Text(
                                          highlight.label,
                                          style: theme.textTheme.labelLarge?.copyWith(
                                            color: highlight.color,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (requestedAt != null)
                                    Text(
                                      _requestedLabel(requestedAt!),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              
                              // Main status description
                              Text(
                                highlight.description,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              // Benefits / Info list
                              _BenefitRow(
                                icon: Icons.shield_moon_outlined,
                                label: 'Credential verification',
                                description: 'Our clinical reviewers confirm your licensure and education to protect the community.',
                              ),
                              const SizedBox(height: 24),
                              _BenefitRow(
                                icon: Icons.timer_outlined,
                                label: 'Typical timeline',
                                description: 'Most approvals are completed within one business day. You will receive an email once approved.',
                              ),
                              const SizedBox(height: 24),
                              _BenefitRow(
                                icon: Icons.mail_outlined,
                                label: 'Need to update details?',
                                description: 'You can revisit your profile to adjust any licensure or education information if requested.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Action Buttons
                      FilledButton(
                        onPressed: refreshing ? null : onRefresh,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: theme.colorScheme.primary,
                          elevation: 0,
                        ),
                        child: refreshing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.refresh_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text('Check status again', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: refreshing ? null : onUpdateProfile,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                          backgroundColor: theme.colorScheme.surface,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_outlined, size: 20, color: theme.colorScheme.onSurface),
                            const SizedBox(width: 8),
                            Text('Update therapist profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: theme.colorScheme.onSurface)),
                          ],
                        ),
                      ),
                      
                      if (onSignOut != null) ...[
                        const SizedBox(height: 24),
                        Center(
                          child: TextButton.icon(
                            onPressed: (refreshing || signingOut) ? null : () async {
                              await onSignOut!.call();
                            },
                            icon: signingOut
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  )
                                : Icon(Icons.logout_rounded, size: 20, color: theme.colorScheme.onSurfaceVariant),
                            label: Text(
                              signingOut ? 'Signing out…' : 'Sign out',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  _ApprovalHighlight _statusHighlight(ThemeData theme, String status) {
    switch (status) {
      case 'approved':
        return _ApprovalHighlight(
          label: 'Approved',
          description: 'Your profile is live. You now have full access to your dashboard and patient tools.',
          color: theme.colorScheme.primary, // Using primary blue for success too in this context to keep it clean, or green? Reference usually uses blue/pending.
          icon: Icons.check_circle_rounded,
        );
      case 'needs_review':
      case 'resubmitted':
        return _ApprovalHighlight(
          label: 'Action Required',
          description: 'We need some additional information to complete your review. Please update your profile.',
          color: Colors.orange,
          icon: Icons.info_rounded,
        );
      case 'pending':
      default:
        return _ApprovalHighlight(
          label: 'Pending review',
          description: 'Our admin team is reviewing your submission. We will notify you as soon as it is approved.',
          color: theme.colorScheme.primary,
          icon: Icons.hourglass_top_rounded,
        );
    }
  }

  String _requestedLabel(DateTime time) {
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
