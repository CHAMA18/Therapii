import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';

/// A reusable, modern-styled drawer with a gradient header and consistent spacing.
///
/// Usage:
/// AppDrawer(
///   title: 'Settings',
///   subtitle: 'Quick actions for your account',
///   children: [...],
/// )
class AppDrawer extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final double width;

  const AppDrawer({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.width = 320,
  });

  String _displayName() {
    final user = FirebaseAuthManager().currentUser;
    final email = user?.email ?? '';
    final local = email.contains('@') ? email.split('@').first : email;
    return local.isNotEmpty ? local : 'Guest';
  }

  String _initials(String name) {
    if (name.trim().isEmpty) return '👤';
    final parts = name.trim().split(RegExp(r"\s+"));
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = _displayName();
    final initials = _initials(name);

    return Drawer(
      width: width,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Theme(
          // Remove splash/highlight for a cleaner, modern feel
          data: theme.copyWith(
            splashFactory: NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            hoverColor: scheme.surfaceContainerHighest,
            listTileTheme: ListTileThemeData(
              iconColor: scheme.primary,
              textColor: scheme.onSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(
                title: title,
                subtitle: subtitle,
                initials: initials,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SectionCard(children: children),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String initials;
  const _Header({required this.title, this.subtitle, required this.initials});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        scheme.primary,
        Color.lerp(scheme.primary, scheme.primaryContainer, 0.45) ?? scheme.primaryContainer,
      ],
    );

    return Container
        (
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: scheme.onPrimary.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.settings, size: 18, color: scheme.onPrimary),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimary.withValues(alpha: 0.9),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Transform.rotate(
            angle: -math.pi / 2,
            child: Icon(Icons.tune, color: scheme.onPrimary.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i != 0)
              Divider(height: 1, color: scheme.outline.withValues(alpha: 0.08)),
            children[i],
          ]
        ],
      ),
    );
  }
}
