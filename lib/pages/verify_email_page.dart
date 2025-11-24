import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as FirebaseAuth;
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/pages/patient_dashboard_page.dart';
import 'package:therapii/pages/patient_onboarding_flow_page.dart';
import 'package:therapii/pages/therapist_welcome_psychology_today_page.dart';
import 'package:therapii/services/user_service.dart';
import 'package:therapii/widgets/primary_button.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;
  final bool isTherapist;
  const VerifyEmailPage({super.key, required this.email, required this.isTherapist});

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final FirebaseAuthManager _authManager = FirebaseAuthManager();
  final UserService _userService = UserService();
  bool _sending = false;
  bool _checking = false;

  FirebaseAuth.User? get _firebaseUser => FirebaseAuth.FirebaseAuth.instance.currentUser;

  Future<void> _sendVerificationEmail() async {
    final user = _firebaseUser;
    if (user == null) return;
    setState(() => _sending = true);
    try {
      await _authManager.sendEmailVerification(user: user);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification email sent to ${widget.email}')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _navigateAfterVerification() async {
    if (!mounted) return;
    final user = _firebaseUser;
    if (user == null) return;

    bool isTherapist = widget.isTherapist;
    bool onboardingCompleted = false;

    try {
      final profile = await _userService.getUser(user.uid);
      isTherapist = profile?.isTherapist ?? isTherapist;
      onboardingCompleted = profile?.patientOnboardingCompleted ?? false;
    } catch (_) {
      // If the user profile can't be loaded we fall back to the provided role hint.
    }

    final destination = isTherapist
        ? const TherapistWelcomePsychologyTodayPage()
        : (onboardingCompleted ? const PatientDashboardPage() : const PatientOnboardingFlowPage());

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  Future<void> _checkVerified() async {
    final user = _firebaseUser;
    if (user == null) return;
    setState(() => _checking = true);
    try {
      await _authManager.refreshUser(user: user);
      final refreshed = FirebaseAuth.FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        if (mounted) {
          await _navigateAfterVerification();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Email not verified yet. Please check your inbox.')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // If the user just signed up, they likely already got a verification email.
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.mark_email_unread, size: 64, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text('Confirm your account', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'We\'ve sent a verification link to ${widget.email}.\nPlease click the link in your email to confirm your account before continuing.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Resend email',
                    onPressed: _sending ? null : _sendVerificationEmail,
                    isLoading: _sending,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _checking ? null : _checkVerified,
                    child: _checking ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('I\'ve verified, continue'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => FirebaseAuth.FirebaseAuth.instance.signOut().then((_) => Navigator.of(context).popUntil((r) => r.isFirst)),
                    child: const Text('Use a different email'),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
