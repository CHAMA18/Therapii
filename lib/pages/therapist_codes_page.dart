import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:therapii/models/invitation_code.dart';
import 'package:therapii/models/user.dart' as app_user;
import 'package:therapii/theme.dart';

typedef InvitationSelectionCallback = Future<void> Function(InvitationCode invitation);

/// Showcases the patient's therapist access codes in a premium, immersive layout.
///
/// Tapping a code invokes [onSelect], allowing the caller to switch the active
/// therapist context without reimplementing selection logic.
class TherapistCodesPage extends StatelessWidget {
  final List<InvitationCode> invitations;
  final Map<String, app_user.User> therapistCache;
  final InvitationSelectionCallback onSelect;

  const TherapistCodesPage({
    super.key,
    required this.invitations,
    required this.therapistCache,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text('Therapist Codes'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _GradientBackdrop(brightness: brightness),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: _HeroSection(totalConnections: invitations.length),
                  ),
                ),
                if (invitations.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final invitation = invitations[index];
                          final therapist = therapistCache[invitation.therapistId];
                          return _AnimatedCodeCard(
                            index: index,
                            invitation: invitation,
                            therapist: therapist,
                            onTap: () => onSelect(invitation),
                          );
                        },
                        childCount: invitations.length,
                      ),
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

class _GradientBackdrop extends StatelessWidget {
  final Brightness brightness;
  const _GradientBackdrop({required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        gradient: AppGradients.primaryFor(brightness),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: _Orb(size: 160, opacity: 0.18),
          ),
          Positioned(
            left: -24,
            bottom: -36,
            child: _Orb(size: 200, opacity: 0.12),
          ),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double size;
  final double opacity;
  const _Orb({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimary.withOpacity(opacity);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color, blurRadius: 80, spreadRadius: 12),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final int totalConnections;
  const _HeroSection({required this.totalConnections});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final subtitle = totalConnections == 0
        ? 'Add an invitation code from your therapist to unlock secure messaging and voice sessions.'
        : 'You have $totalConnections connected ${totalConnections == 1 ? 'therapist' : 'therapists'}. Tap any card below to jump into that relationship instantly.';

    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacity(0.08),
              blurRadius: 40,
              offset: const Offset(0, 22),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_rounded, color: scheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    totalConnections == 0
                        ? 'No connections yet'
                        : totalConnections == 1
                            ? '1 active connection'
                            : '$totalConnections active connections',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Switch therapists effortlessly',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCodeCard extends StatelessWidget {
  final int index;
  final InvitationCode invitation;
  final app_user.User? therapist;
  final VoidCallback onTap;

  const _AnimatedCodeCard({
    required this.index,
    required this.invitation,
    required this.therapist,
    required this.onTap,
  });

  String _displayName() {
    if (therapist == null) return 'Therapist';
    final fullName = therapist!.fullName.trim();
    if (fullName.isEmpty || fullName == ' ') {
      return therapist!.email;
    }
    return fullName;
  }

  String _initials() {
    final name = _displayName().trim();
    if (name.isEmpty) return 'T';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  String _formatDate(BuildContext context, DateTime date) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatMediumDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final connectedOn = invitation.usedAt ?? invitation.createdAt;
    final isActive = invitation.isUsed;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + (index * 30)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, (1 - value) * 28),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withOpacity(0.06),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: scheme.primary.withOpacity(0.12),
                        child: Text(
                          _initials(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _displayName(),
                                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                _StatusPill(isActive: isActive),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Connected since ${_formatDate(context, connectedOn)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: scheme.surfaceContainerHighest.withOpacity(0.18),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.key_rounded, color: scheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            invitation.code,
                            style: theme.textTheme.titleMedium?.copyWith(
                              letterSpacing: 1.2,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_outward_rounded, color: scheme.primary),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Tap to switch to this therapist profile and continue your conversation seamlessly.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isActive;
  const _StatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = isActive ? scheme.primary : scheme.tertiary;
    final label = isActive ? 'Active' : 'Pending activation';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isActive ? Icons.bolt_rounded : Icons.hourglass_top_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withOpacity(0.12),
            ),
            child: Icon(Icons.key_rounded, color: scheme.primary, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            'No invitation codes yet',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'When your therapist shares a code, paste it in your dashboard to securely link your care teams here.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5, color: scheme.onSurface.withOpacity(0.7)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}