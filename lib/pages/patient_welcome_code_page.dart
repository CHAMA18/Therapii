import 'package:flutter/material.dart';
import 'package:therapii/widgets/primary_button.dart';
import 'package:therapii/services/invitation_service.dart';
import 'package:therapii/models/invitation_code.dart';
import 'package:therapii/services/user_service.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/pages/home_page.dart';
import 'package:therapii/pages/auth_welcome_page.dart';
import 'package:therapii/pages/patient_dashboard_page.dart';
import 'package:therapii/pages/patient_invitation_signup_page.dart';

class PatientWelcomeCodePage extends StatefulWidget {
  const PatientWelcomeCodePage({super.key});

  @override
  State<PatientWelcomeCodePage> createState() => _PatientWelcomeCodePageState();
}

class _PatientWelcomeCodePageState extends State<PatientWelcomeCodePage> {
  final TextEditingController _codeCtrl = TextEditingController();
  final _invitationService = InvitationService();
  final _userService = UserService();
  bool _noCode = false;
  bool _submitting = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  String? _validateCode(String v) {
    if (_noCode) return null;
    final code = v.trim();
    if (code.isEmpty) return 'Please enter your 5-digit code';
    if (!RegExp(r'^\d{5}$').hasMatch(code)) return 'Code must be 5 digits';
    return null;
  }

  Future<void> _continue() async {
    if (!_noCode) {
      final err = _validateCode(_codeCtrl.text);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      final currentUser = FirebaseAuthManager().currentUser;

      if (_noCode) {
        // User doesn't have a code - proceed without linking to therapist
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
        return;
      }

      // Validate the invitation code
      final code = _codeCtrl.text.trim();

      // If authenticated, consume code and link immediately; else preview and carry forward
      InvitationCode? invitation;
      if (currentUser != null) {
        invitation = await _invitationService.validateAndUseCode(
          code: code,
          patientId: currentUser.uid,
        );
      } else {
        invitation = await _invitationService.previewValidCode(code);
      }

      if (invitation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid or expired code. Please check with your therapist.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // invitation is non-null here; capture in a final for closures
      final InvitationCode inv = invitation;

      if (currentUser != null) {
        // Link patient to therapist in user record
        await _userService.linkPatientToTherapist(
          userId: currentUser.uid,
          therapistId: inv.therapistId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully connected to your therapist!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => PatientDashboardPage(therapistId: inv.therapistId)),
          );
        }
      } else {
        // Not authenticated: store pending invitation and route to Create Account to finish linking post-auth
        InvitationService.pendingInvitation = inv;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Code verified for ${inv.patientFirstName}. Create your account to continue.'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PatientInvitationSignupPage(invitation: inv),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Welcome'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text(
                    'Follow these instructions to complete your\nregistration',
                    style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.8), height: 1.3),
                  ),
                  const SizedBox(height: 32),
                  Text('Welcome to Therapii!', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text(
                    'To complete your registration as a patient, you need to be\nassociated with a licensed therapist who is seeing you.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface.withValues(alpha: 0.9), height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'If they already provided you with a 5-digit code, you can enter it below.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface.withValues(alpha: 0.9), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Switch(
                        value: _noCode,
                        onChanged: (v) => setState(() => _noCode = v),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'I do not have a code from my therapist',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeCtrl,
                    enabled: !_noCode,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Enter 5-Digit Code',
                      filled: true,
                      fillColor: scheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) {
                      final p = v.replaceAll(RegExp(r'[^0-9]'), '');
                      if (p != v) {
                        final sel = TextSelection.collapsed(offset: p.length);
                        _codeCtrl.value = TextEditingValue(text: p, selection: sel);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  PrimaryButton(label: 'Continue', isLoading: _submitting, onPressed: _submitting ? null : _continue),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                       onPressed: () {
                         Navigator.of(context).pushReplacement(
                           MaterialPageRoute(
                             builder: (_) => const AuthWelcomePage(initialTab: AuthTab.login),
                           ),
                         );
                       },
                        child: const Text('Authentication'),
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
