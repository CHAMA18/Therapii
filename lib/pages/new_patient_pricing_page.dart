import 'package:flutter/material.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/pages/auth_welcome_page.dart';
import 'package:therapii/pages/new_patient_confirm_page.dart';

class NewPatientPricingPage extends StatelessWidget {
  final String patientName;
  final String patientEmail;
  final String invitationCode;

  const NewPatientPricingPage({
    super.key,
    required this.patientName,
    required this.patientEmail,
    required this.invitationCode,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final brandTeal = scheme.tertiary; // matches the Therapii wordmark color in screenshots
    final greyText = Colors.grey.shade700;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Therapii', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: brandTeal, fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              await FirebaseAuthManager().signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthWelcomePage(initialTab: AuthTab.login)),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  Text('New Patient Pricing', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'We offer standard pricing as well as a program to support patients who may need financial assistance.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: greyText),
                  ),
                  const SizedBox(height: 16),

                  _InfoCard(children: [
                    Text(
                      'Our pricing is a \$150 monthly fee for unlimited use of Therapii. This fee is paid by the patient and can be canceled at any time. (Please note: we are unable to accept insurance at this time.)',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9ECF3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Therapii will retain \$50 of this fee for platform use. The remaining amount will be paid directly to you.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade800),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  _InfoCard(children: [
                    Text('As part of our launch, we are offering', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _Bullet(text: '12 free credits that you can extend to your patients, each good for one free month of Therapii', dotColor: primary),
                    const SizedBox(height: 10),
                    _Bullet(text: '12 additional credits for every new therapist you invite to join Therapil', dotColor: primary),
                    const SizedBox(height: 10),
                    _Bullet(
                      text: 'If you need more free credits to support a patient in need, please contact us at support@therapii.com',
                      dotColor: primary,
                      highlight: 'support@therapii.com',
                    ),
                  ]),

                  const SizedBox(height: 24),

                  Center(
                    child: SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => NewPatientConfirmPage(
                                patientName: patientName,
                                patientEmail: patientEmail,
                                invitationCode: invitationCode,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3F62A8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 2,
                        ),
                        child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  final String? highlight;
  final Color dotColor;
  const _Bullet({required this.text, required this.dotColor, this.highlight});

  @override
  Widget build(BuildContext context) {
    final parts = highlight != null && text.contains(highlight!)
        ? text.split(highlight!)
        : [text];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
              children: highlight != null && parts.length == 2
                  ? [
                      TextSpan(text: parts[0]),
                      TextSpan(text: highlight!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                      TextSpan(text: parts[1]),
                    ]
                  : [TextSpan(text: text)],
            ),
          ),
        ),
      ],
    );
  }
}
