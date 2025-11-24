import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/models/invitation_code.dart';
import 'package:therapii/pages/patient_invitation_payment_page.dart';
import 'package:therapii/services/invitation_service.dart';
import 'package:therapii/services/user_service.dart';
import 'package:therapii/widgets/primary_button.dart';

class PatientInvitationSignupPage extends StatefulWidget {
  final InvitationCode invitation;
  const PatientInvitationSignupPage({super.key, required this.invitation});

  @override
  State<PatientInvitationSignupPage> createState() => _PatientInvitationSignupPageState();
}

class _PatientInvitationSignupPageState extends State<PatientInvitationSignupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  final FirebaseAuthManager _authManager = FirebaseAuthManager();
  final InvitationService _invitationService = InvitationService();
  final UserService _userService = UserService();

  bool _isSubmitting = false;
  bool _agreeTos = false;
  bool _agreePrivacy = false;

  @override
  void initState() {
    super.initState();
    final invitation = widget.invitation;
    InvitationService.pendingInvitation = invitation;
    _firstNameCtrl = TextEditingController(text: invitation.patientFirstName);
    _lastNameCtrl = TextEditingController(text: invitation.patientLastName);
    _emailCtrl = TextEditingController(text: invitation.patientEmail);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {bool readOnly = false}) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6), width: 1.2)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.2))),
    ).copyWith(
      labelStyle: readOnly ? Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor) : null,
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (!_agreeTos || !_agreePrivacy) {
      messenger.showSnackBar(const SnackBar(content: Text('Please agree to the Terms of Service and Privacy Policy.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      final firstName = _firstNameCtrl.text.trim();
      final lastName = _lastNameCtrl.text.trim();

      final created = await _authManager.createAccountWithEmail(
        context,
        email,
        password,
        isTherapist: false,
      );
      if (created == null) {
        return;
      }

      final userId = created.id;

      await _userService.updateProfile(
        userId: userId,
        firstName: firstName,
        lastName: lastName,
        isTherapist: false,
      );

      await _userService.linkPatientToTherapist(
        userId: userId,
        therapistId: widget.invitation.therapistId,
      );

      final applied = await _invitationService.validateAndUseCode(
        code: widget.invitation.code,
        patientId: userId,
      );

      if (applied == null) {
        throw Exception('This invitation code is no longer valid. Please request a new one from your therapist.');
      }

      InvitationService.pendingInvitation = null;

      final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
      final displayName = [firstName, lastName].where((value) => value.isNotEmpty).join(' ').trim();
      bool requiresEmailVerification = false;
      if (authUser != null && displayName.isNotEmpty) {
        await authUser.updateDisplayName(displayName);
      }

      if (authUser != null && !authUser.emailVerified) {
        await _authManager.sendEmailVerification(user: authUser);
        requiresEmailVerification = true;
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PatientInvitationPaymentPage(
            invitation: widget.invitation,
            patientFirstName: firstName,
            patientLastName: lastName,
            patientEmail: email,
            requiresEmailVerification: requiresEmailVerification,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to create account: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final invitation = widget.invitation;
    final invitationName = invitation.patientFullName.isNotEmpty
        ? invitation.patientFullName
        : invitation.patientFirstName;
    final inviterDescription = invitationName.isNotEmpty
        ? "$invitationName's therapist"
        : 'your therapist';

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Complete Your Registration'),
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Verify your details', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'We found your invitation from $inviterDescription. Confirm your details below and set a password to finish creating your account.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.75), height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _firstNameCtrl,
                      decoration: _fieldDecoration('First name'),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'First name is required.' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameCtrl,
                      decoration: _fieldDecoration('Last name'),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Last name is required.' : null,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      readOnly: true,
                      decoration: _fieldDecoration('Email address', readOnly: true),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: _fieldDecoration('Password'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter a password.';
                        if (value.length < 6) return 'Password must be at least 6 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: true,
                      decoration: _fieldDecoration('Confirm password'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Confirm your password.';
                        if (value != _passwordCtrl.text) return 'Passwords do not match.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: _agreeTos,
                      onChanged: (v) => setState(() => _agreeTos = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text.rich(TextSpan(children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Therapii Terms of Service',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrl(Uri.parse('https://trytherapii.com/?page_id=115'), mode: LaunchMode.platformDefault);
                            },
                        ),
                      ])),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      value: _agreePrivacy,
                      onChanged: (v) => setState(() => _agreePrivacy = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text.rich(TextSpan(children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Therapii Privacy Policy',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              launchUrl(Uri.parse('https://trytherapii.com/?page_id=3'), mode: LaunchMode.platformDefault);
                            },
                        ),
                      ])),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Create Account',
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}