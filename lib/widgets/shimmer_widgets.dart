import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Global shimmer colors tuned for light/dark themes.
class AppShimmers {
  static Shimmer shimmer({required BuildContext context, required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Create gentle, theme-aware shimmer base/highlight colors
    final base = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.14)
        : theme.colorScheme.onSurface.withValues(alpha: 0.08);
    final highlight = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.24)
        : theme.colorScheme.onSurface.withValues(alpha: 0.12);
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      period: const Duration(milliseconds: 1300),
      child: child,
    );
  }

  static Widget box({required BuildContext context, double? width, double? height, BorderRadius? radius}) {
    final scheme = Theme.of(context).colorScheme;
    return shimmer(
      context: context,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: radius ?? BorderRadius.circular(12),
        ),
      ),
    );
  }

  static Widget circle({required BuildContext context, double size = 40}) {
    final scheme = Theme.of(context).colorScheme;
    return shimmer(
      context: context,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Skeleton approximating a list tile with an avatar, title and subtitle.
class ShimmerListTile extends StatelessWidget {
  final double avatarSize;
  final double titleWidth;
  final double subtitleWidth;
  final EdgeInsetsGeometry padding;
  final double height;
  final bool showTrailing;

  const ShimmerListTile({
    super.key,
    this.avatarSize = 44,
    this.titleWidth = 160,
    this.subtitleWidth = 120,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.height = 72,
    this.showTrailing = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      padding: padding,
      child: Row(
        children: [
          AppShimmers.circle(context: context, size: avatarSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppShimmers.box(context: context, width: titleWidth, height: 16, radius: BorderRadius.circular(8)),
                const SizedBox(height: 8),
                AppShimmers.box(context: context, width: subtitleWidth, height: 12, radius: BorderRadius.circular(8)),
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 8),
            AppShimmers.box(context: context, width: 80, height: 28, radius: BorderRadius.circular(8)),
          ],
        ],
      ),
    );
  }
}

/// Skeleton approximating an invitation tile, with code pill and timer text.
class ShimmerInviteTile extends StatelessWidget {
  const ShimmerInviteTile({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppShimmers.circle(context: context, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmers.box(context: context, width: 160, height: 16, radius: BorderRadius.circular(8)),
                const SizedBox(height: 6),
                AppShimmers.box(context: context, width: 200, height: 12, radius: BorderRadius.circular(8)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    AppShimmers.box(context: context, width: 100, height: 24, radius: BorderRadius.circular(8)),
                    const SizedBox(width: 8),
                    AppShimmers.box(context: context, width: 120, height: 12, radius: BorderRadius.circular(8)),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppShimmers.box(context: context, width: 36, height: 36, radius: BorderRadius.circular(10)),
        ],
      ),
    );
  }
}
