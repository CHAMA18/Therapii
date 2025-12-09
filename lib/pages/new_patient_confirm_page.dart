import 'package:flutter/material.dart';
import 'package:therapii/pages/my_patients_page.dart';

class NewPatientConfirmPage extends StatelessWidget {
  final String patientName;
  final String patientEmail;
  final String invitationCode;
  final bool emailSent;

  const NewPatientConfirmPage({
    super.key,
    required this.patientName,
    required this.patientEmail,
    required this.invitationCode,
    this.emailSent = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final grey = Colors.grey.shade700;

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
        title: const Text('New Patient Confirm'),
        centerTitle: true,
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
                  Text('New Patient Confirm', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Information ready for the new patient to register with Therapii', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: grey)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary.withValues(alpha: 0.1), Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: primary.withValues(alpha: 0.2), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_rounded, color: primary, size: 56),
                        const SizedBox(height: 16),
                        Text(
                          emailSent ? 'Invitation Sent Successfully!' : 'Invitation Created',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          emailSent
                              ? 'An email has been sent to $patientName at $patientEmail'
                              : 'We could not send the email automatically. Please share the code below with $patientName at $patientEmail.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'INVITATION CODE',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: grey,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // Make the invitation code row responsive to available width.
                            final chars = invitationCode.split('');
                            final count = chars.length;
                             // Outer padding inside the white card (left+right)
                             const innerHorizontalPadding = 48.0; // 24 + 24 padding
                             const gap = 12.0; // space between boxes
                             const safety = 6.0; // small margin to avoid float/border rounding overflows
 
                             // Compute available width for boxes only (excluding gaps and padding + safety)
                             final rawAvailable = constraints.maxWidth - innerHorizontalPadding - safety - (gap * (count - 1));
                             final clampedAvailable = rawAvailable.clamp(120.0, constraints.maxWidth);
 
                             // Target box width within sane limits so it never overflows
                             final boxWidth = (clampedAvailable / count).clamp(34.0, 64.0);
                             final fontSize = boxWidth * 0.6 + 8; // scale text with box size

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: primary.withValues(alpha: 0.3), width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (int i = 0; i < count; i++) ...[
                                    Container(
                                      width: boxWidth,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: primary.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: primary.withValues(alpha: 0.2)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        chars[i],
                                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: primary,
                                              fontSize: fontSize.clamp(20.0, 36.0),
                                            ),
                                      ),
                                    ),
                                    if (i != count - 1) const SizedBox(width: gap),
                                  ]
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  emailSent
                                      ? 'You can share this code directly if the patient doesn\'t receive the email'
                                      : 'Share this code with the patient now. If you recently verified your sender email in SendGrid, try again in a few minutes.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.blue.shade800,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const MyPatientsPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3F62A8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
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
 
