import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:therapii/theme.dart';
import 'package:therapii/widgets/primary_button.dart';

/// A concierge-style support hub with rich visuals and direct contact actions.
class SupportCenterPage extends StatelessWidget {
  const SupportCenterPage({super.key});

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!success && context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('We couldn\'t open that link. Please try again in a browser.')),
      );
    }
  }

  void _showDocumentSheet(BuildContext context, {required String title, required String body}) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Text(body, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6)),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final quickActions = [
      _SupportAction(
        icon: Icons.mail_outline_rounded,
        title: 'Email our care team',
        description: 'Reach a licensed specialist in under 2 hours.',
        onTap: () => _launchUri(context, Uri.parse('mailto:support@trytherapii.com?subject=Therapii%20Support%20Request')),
      ),
      _SupportAction(
        icon: Icons.calendar_month_rounded,
        title: 'Schedule a support call',
        description: 'Book a 1:1 onboarding or troubleshooting session.',
        onTap: () => _launchUri(context, Uri.parse('https://trytherapii.com/support/call')),
      ),
      _SupportAction(
        icon: Icons.bar_chart_rounded,
        title: 'View system status',
        description: 'Check live uptime and incident reports.',
        onTap: () => _launchUri(context, Uri.parse('https://status.trytherapii.com')),
      ),
    ];

    final faqs = const [
      _FaqItem(
        question: 'How do therapist codes work?',
        answer:
            'Each invitation code is generated uniquely for you by a therapist. Entering or tapping a code connects your profile, unlocking secure messaging, AI summaries, and voice sessions. Codes expire automatically for safety.',
      ),
      _FaqItem(
        question: 'How soon will support respond?',
        answer:
            'Therapii\'s concierge team responds within two business hours. Urgent clinical matters should always be routed to emergency services rather than the in-app support desk.',
      ),
      _FaqItem(
        question: 'Can I export my session history?',
        answer:
            'Yes. Visit Settings → Privacy → Export data. You can request a secure archive of chats, voice transcriptions, and AI summaries, delivered via encrypted email within 24 hours.',
      ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text('Support'),
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
            child: _SupportBackdrop(brightness: theme.brightness),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                    child: _HeroBanner(),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  sliver: SliverToBoxAdapter(
                    child: _QuickActionsGrid(actions: quickActions),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
                  sliver: SliverToBoxAdapter(
                    child: _ConciergeCard(
                      onRequestFollowUp: () => _launchUri(
                        context,
                        Uri.parse('https://trytherapii.com/support/request'),
                      ),
                      onShowPrivacy: () => _showDocumentSheet(
                        context,
                        title: 'Privacy at Therapii',
                        body: _privacyCopy,
                      ),
                      onShowTerms: () => _showDocumentSheet(
                        context,
                        title: 'Terms & Usage',
                        body: _termsCopy,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _FaqCard(item: faqs[index], index: index),
                      childCount: faqs.length,
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

class _SupportBackdrop extends StatelessWidget {
  final Brightness brightness;
  const _SupportBackdrop({required this.brightness});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        gradient: AppGradients.primaryFor(brightness),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            right: -26,
            top: -38,
            child: _FrostedOrb(size: 150, opacity: 0.18),
          ),
          Positioned(
            left: -32,
            bottom: -30,
            child: _FrostedOrb(size: 210, opacity: 0.12),
          ),
        ],
      ),
    );
  }
}

class _FrostedOrb extends StatelessWidget {
  final double size;
  final double opacity;
  const _FrostedOrb({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimary.withOpacity(opacity);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 70, spreadRadius: 14)],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: scheme.primary.withOpacity(0.08), blurRadius: 36, offset: const Offset(0, 22)),
        ],
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.headset_mic_rounded, color: scheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Concierge Support',
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "We're here, every step of the way",
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            'Get instant guidance on onboarding, billing, therapist codes, or AI voice sessions. Our support specialists know Therapii inside and out.',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _SupportAction {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _SupportAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });
}

class _QuickActionsGrid extends StatelessWidget {
  final List<_SupportAction> actions;
  const _QuickActionsGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 620;
        final crossAxisCount = isWide ? 3 : 1;
        final spacing = 16.0;
        final itemWidth = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(0, (1 - value) * 22),
                    child: Opacity(opacity: value, child: child),
                  ),
                  child: Material(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: action.onTap,
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 46,
                              width: 46,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: scheme.primary.withOpacity(0.12),
                              ),
                              child: Icon(action.icon, color: scheme.primary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              action.title,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              action.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withOpacity(0.7),
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ConciergeCard extends StatelessWidget {
  final VoidCallback onRequestFollowUp;
  final VoidCallback onShowPrivacy;
  final VoidCallback onShowTerms;
  const _ConciergeCard({
    required this.onRequestFollowUp,
    required this.onShowPrivacy,
    required this.onShowTerms,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: scheme.surface,
        boxShadow: [
          BoxShadow(color: scheme.primary.withOpacity(0.07), blurRadius: 40, offset: const Offset(0, 24)),
        ],
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.primaryContainer],
                  ),
                ),
                child: Icon(Icons.favorite_rounded, color: scheme.onPrimary),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Concierge follow-up', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      'Prefer us to reach out? Share a few details and a specialist will respond with a tailored plan.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45, color: scheme.onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Request a concierge follow-up',
            onPressed: onRequestFollowUp,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShowPrivacy,
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: const Text('Privacy commitments'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShowTerms,
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('Terms snapshot'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}

class _FaqCard extends StatelessWidget {
  final _FaqItem item;
  final int index;
  const _FaqCard({required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, (1 - value) * 24),
        child: Opacity(opacity: value, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: scheme.surface,
          boxShadow: [
            BoxShadow(color: scheme.primary.withOpacity(0.05), blurRadius: 26, offset: const Offset(0, 18)),
          ],
        ),
        child: ExpansionTile(
          initiallyExpanded: index == 0,
          tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
          title: Text(item.question, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          children: [
            Text(
              item.answer,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55, color: scheme.onSurface.withOpacity(0.75)),
            ),
          ],
        ),
      ),
    );
  }
}

const String _privacyCopy =
    'Your messages, voice sessions, and AI summaries are encrypted at rest and in transit. Only you and verified members of your care team can unlock them. We regularly rotate encryption keys and maintain HIPAA-aligned audit logs. Review the full privacy policy inside the secure web portal.';

const String _termsCopy =
    'Therapii pairs patients and therapists with intelligent copilots for care. Using the platform means you agree to respect confidentiality, refrain from sharing medical emergencies inside the app, and understand that AI-generated insights are advisory—not a substitute for professional judgment.';