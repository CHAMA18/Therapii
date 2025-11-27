import 'package:flutter/material.dart';
import 'package:therapii/theme.dart';

/// A premium, animated action card used across dashboards.
///
/// Supports a primary gradient state, secondary outline state, and disabled state
/// with an optional action chip label.
class DashboardActionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isSecondary;
  final bool isDisabled;
  final String? actionLabel;

  const DashboardActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.isPrimary = false,
    this.isSecondary = false,
    this.isDisabled = false,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final gradient = isPrimary ? AppGradients.primaryFor(theme.brightness) : null;

    Color backgroundColor;
    Color iconColor;
    Color titleColor;
    Color subtitleColor;

    if (isDisabled) {
      backgroundColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.2);
      iconColor = colorScheme.onSurface.withValues(alpha: 0.2);
      titleColor = colorScheme.onSurface.withValues(alpha: 0.3);
      subtitleColor = colorScheme.onSurface.withValues(alpha: 0.2);
    } else if (isPrimary) {
      backgroundColor = colorScheme.primary;
      iconColor = colorScheme.onPrimary;
      titleColor = colorScheme.onPrimary;
      subtitleColor = colorScheme.onPrimary.withValues(alpha: 0.9);
    } else {
      backgroundColor = colorScheme.surface;
      iconColor = colorScheme.primary;
      titleColor = colorScheme.onSurface;
      subtitleColor = colorScheme.onSurfaceVariant;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: gradient,
        color: gradient == null ? backgroundColor : null,
        border: (isPrimary || isDisabled)
            ? null
            : Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
        boxShadow: [
          if (!isDisabled && isPrimary)
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          else if (!isDisabled)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(32),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: isPrimary ? Colors.white.withValues(alpha: 0.1) : colorScheme.primary.withValues(alpha: 0.05),
          highlightColor: isPrimary ? Colors.white.withValues(alpha: 0.05) : colorScheme.primary.withValues(alpha: 0.02),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDisabled
                            ? Colors.transparent
                            : (isPrimary
                                ? Colors.white.withValues(alpha: 0.2)
                                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: 32,
                      ),
                    ),
                    if (isPrimary && !isDisabled)
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 24,
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        height: 1.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: subtitleColor,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (actionLabel != null && isDisabled) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          actionLabel!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ]
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
