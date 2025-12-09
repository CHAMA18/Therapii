import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as FirebaseAuth;
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/pages/patient_dashboard_page.dart';
import 'package:therapii/pages/patient_onboarding_flow_page.dart';
import 'package:therapii/pages/therapist_welcome_psychology_today_page.dart';
import 'package:therapii/services/user_service.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // We want a clean, bright look primarily, but support dark mode nicely
    final backgroundColor = isDark ? theme.scaffoldBackgroundColor : Colors.white;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final bodyColor = isDark ? Colors.grey[400] : const Color(0xFF5F6368);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Verify your email',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: titleColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            Icons.mark_email_unread_rounded,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Main Title
                        Text(
                          'Confirm your account',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: titleColor,
                            fontSize: 24,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        
                        // Body Text
                        Text(
                          'We\'ve sent a verification link to\n${widget.email}.\nPlease click the link in your email to confirm your\naccount before continuing.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: bodyColor,
                            height: 1.5,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        
                        // Resend Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _sending ? null : _sendVerificationEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _sending 
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                              : const Text(
                                  'RESEND EMAIL',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                                ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Verified Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _checking ? null : _checkVerified,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300, width: 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              backgroundColor: isDark ? Colors.transparent : Colors.white,
                              foregroundColor: isDark ? Colors.white : Colors.black87,
                              elevation: 0,
                            ),
                            child: _checking 
                              ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary)) 
                              : const Text(
                                  'I\'ve verified, continue',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Different Email
                        TextButton(
                          onPressed: () => FirebaseAuth.FirebaseAuth.instance.signOut().then((_) => Navigator.of(context).popUntil((r) => r.isFirst)),
                          child: Text(
                            'Use a different email',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
