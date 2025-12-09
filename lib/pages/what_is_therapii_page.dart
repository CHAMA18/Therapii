import 'package:flutter/material.dart';
import 'package:therapii/pages/auth_welcome_page.dart';
import 'package:therapii/theme.dart';

class WhatIsTherapiiPage extends StatelessWidget {
  const WhatIsTherapiiPage({super.key});

  void _goToAuth(BuildContext context, {bool login = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthWelcomePage(initialTab: login ? AuthTab.login : AuthTab.create),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borderOrange = const Color(0xFFFF7F50); // soft orange accent

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const _LogoBadge(),
                const SizedBox(height: 8),
                _SurfaceCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text('What is Therapii?', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: () => _goToAuth(context, login: true),
                        child: Text('Login', style: textTheme.titleMedium?.copyWith(color: cs.primary)),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SurfaceCard(
                  child: Text(
                    'Therapii is an AI based tool that allows a patient to continue their therapeutic program outside of their session times via a chatbot that has been trained by the patient\'s therapist to understand the patient\'s needs and therapeutic objectives.',
                    style: textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: 20),
                _OutlinedChecklist(
                  title: 'With Therapii, therapists are able to:',
                  bullets: const [
                    'Personalize an AI agent that is already trained on broad therapeutic modalities to reflect their individual style, language and approach to therapy. Initial training takes less than an hour, and then the agent continually learns and grows with continued interaction.',
                    'Extend their time with patients beyond the typical 1 hour per week, guiding their agent on things to listen for, questions to ask or topics to explore. All engagements with the patient are recorded and summarized for the therapist daily.',
                    'Earn extra income from use of the app while setting custom pricing that is appropriate to you and your patients.',
                  ],
                  borderColor: borderOrange,
                ),
                const SizedBox(height: 20),
                _OutlinedChecklist(
                  title: 'With Therapii, therapists are able to:',
                  bullets: const [
                    'Ask questions and get responses that mirror the therapist\'s style and objectives 24/7....your therapist is always available. Whether you are between classes, taking a break from work, on a morning walk or getting ready for bed, your therapist is always available for you.',
                    'Provide a very personal experience. Unlike ChatGPT or social media, the AI therapist reflects your therapist and their therapeutic plan for you and is continually learning from you, your therapist and your interactions.',
                    'Get the notes and summaries of your interactions with your IRL therapist and your AI therapist companion. You don\'t have to wonder "what was that thing they said?" because your AI therapist is there taking notes for you.',
                  ],
                  borderColor: borderOrange,
                ),
                const SizedBox(height: 28),
                _PrimaryCTA(
                  label: 'Get Started',
                  onPressed: () => _goToAuth(context, login: false),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.center,
      child: CircleAvatar(
        radius: 28,
        backgroundColor: cs.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/images/therapii_logo.png', fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  const _SurfaceCard({required this.child});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: child,
    );
  }
}

class _OutlinedChecklist extends StatelessWidget {
  final String title;
  final List<String> bullets;
  final Color borderColor;
  const _OutlinedChecklist({required this.title, required this.bullets, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...bullets.map((b) => _CheckBullet(text: b, color: borderColor)),
      ]),
    );
  }
}

class _CheckBullet extends StatelessWidget {
  final String text;
  final Color color;
  const _CheckBullet({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Icon(Icons.check, color: color, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: textTheme.bodyLarge),
        ),
      ]),
    );
  }
}

class _PrimaryCTA extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PrimaryCTA({required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(cs.primary),
          foregroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        icon: const Icon(Icons.arrow_forward),
        label: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
