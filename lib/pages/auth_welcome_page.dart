import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' as FirebaseAuth;
import 'package:therapii/widgets/form_fields.dart';
import 'package:therapii/widgets/primary_button.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/services/user_service.dart';
import 'package:therapii/pages/admin_dashboard_page.dart';
import 'package:therapii/pages/my_patients_page.dart';
import 'package:therapii/pages/patient_dashboard_page.dart';
import 'package:therapii/pages/patient_onboarding_flow_page.dart';
import 'package:therapii/pages/patient_welcome_code_page.dart';
import 'package:therapii/pages/verify_email_page.dart';
import 'package:therapii/services/invitation_service.dart';
import 'package:therapii/models/invitation_code.dart';
import 'package:therapii/utils/admin_access.dart';
import 'package:url_launcher/url_launcher.dart';

enum AuthTab { create, login }
enum AccountRole { therapist, patient }

class AuthWelcomePage extends StatefulWidget {
  final AuthTab initialTab;
  const AuthWelcomePage({super.key, this.initialTab = AuthTab.create});

  @override
  State<AuthWelcomePage> createState() => _AuthWelcomePageState();
}

class _AuthWelcomePageState extends State<AuthWelcomePage> {
  late AuthTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 16),
                _Header(),
                const SizedBox(height: 16),
                _Tabs(tab: _tab, onChanged: (t) => setState(() => _tab = t)),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _tab == AuthTab.create ? const _CreateAccountForm(key: ValueKey('create')) : const _LoginForm(key: ValueKey('login')),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Image.asset('assets/images/therapii_logo.png', height: 180, fit: BoxFit.contain),
      const SizedBox(height: 24),
      Text('Welcome', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _Tabs extends StatelessWidget {
  final AuthTab tab;
  final ValueChanged<AuthTab> onChanged;
  const _Tabs({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final grey = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    Widget buildItem(String label, AuthTab value) {
      final selected = tab == value;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: selected ? scheme.onSurface : grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Container(height: 2, color: selected ? scheme.primary : Colors.transparent),
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      buildItem('Create Account', AuthTab.create),
      const SizedBox(width: 12),
      buildItem('Log in', AuthTab.login),
    ]);
  }
}

class _CreateAccountForm extends StatefulWidget {
  const _CreateAccountForm({super.key});

  @override
  State<_CreateAccountForm> createState() => _CreateAccountFormState();
}

class _CreateAccountFormState extends State<_CreateAccountForm> {
  final nameCtl = TextEditingController();
  final emailCtl = TextEditingController();
  final passCtl = TextEditingController();
  final confirmCtl = TextEditingController();
  bool agreeTos = false;
  bool agreePrivacy = false;
  bool _isLoading = false;
  final FirebaseAuthManager _authManager = FirebaseAuthManager();
  AccountRole? _role; // Require explicit selection; no default

  // Avatar selection
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String? _avatarPreviewUrl; // For showing uploaded URL if we upload after creation

  @override
  void dispose() {
    nameCtl.dispose();
    emailCtl.dispose();
    passCtl.dispose();
    confirmCtl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Prefill from a pending invitation if present
    final pending = InvitationService.pendingInvitation;
    if (pending != null) {
      final composedName = pending.patientFullName.trim();
      nameCtl.text = composedName.isNotEmpty ? composedName : pending.patientFirstName;
      emailCtl.text = pending.patientEmail;
      _role = AccountRole.patient; // Invitation implies patient
    }
  }

  Future<void> _pickAvatar() async {
    try {
      debugPrint('[Auth] Avatar tap detected. Opening file picker...');
      final typeGroup = const XTypeGroup(label: 'Images', extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp']);
      final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) {
        debugPrint('[Auth] File picker canceled.');
        return;
      }
      final bytes = await file.readAsBytes();
      debugPrint('[Auth] Picked file: name=${file.name}, size=${bytes.length}');
      setState(() {
        _avatarBytes = bytes;
        _avatarFileName = file.name;
        _avatarPreviewUrl = null;
      });
    } catch (e, st) {
      debugPrint('[Auth] Error picking image (file_selector): $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not pick image.')));
    }
  }

  Future<String?> _uploadAvatar(String userId) async {
    if (_avatarBytes == null) return null;
    try {
      final ext = (_avatarFileName ?? 'avatar').split('.').last.toLowerCase();
      final ref = FirebaseStorage.instance.ref('user_avatars/$userId/profile.$ext');
      final metadata = SettableMetadata(contentType: 'image/${ext == 'jpg' ? 'jpeg' : ext}');
      await ref.putData(_avatarBytes!, metadata);
      final url = await ref.getDownloadURL();
      setState(() => _avatarPreviewUrl = url);
      return url;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to upload avatar.')));
      return null;
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.platformDefault);
  }

  Widget _buildRoleSelector(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final borderColor = theme.dividerColor.withValues(alpha: 0.4);

    Widget buildOption(String label, AccountRole role) {
      final selected = _role == role;
      final baseStyle = theme.textTheme.bodyMedium ?? const TextStyle();
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isLoading
                ? null
                : () {
                    setState(() => _role = role);
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected ? scheme.primary.withValues(alpha: 0.15) : scheme.surface,
                border: selected ? Border.all(color: scheme.primary, width: 1.5) : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: baseStyle.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? scheme.primary : baseStyle.color,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          buildOption('Therapist', AccountRole.therapist),
          Container(
            width: 1.5,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: borderColor,
          ),
          buildOption('Patient', AccountRole.patient),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_role == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Please select account type: Therapist or Patient.')));
      return;
    }
    if (!agreeTos || !agreePrivacy) {
      messenger.showSnackBar(const SnackBar(content: Text('Please agree to Terms of Service and Privacy Policy.')));
      return;
    }
    if (nameCtl.text.isEmpty || emailCtl.text.isEmpty || passCtl.text.isEmpty || confirmCtl.text.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Fill in all fields.')));
      return;
    }
    if (passCtl.text != confirmCtl.text) {
      messenger.showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isTherapist = _role == AccountRole.therapist;
      final created = await _authManager.createAccountWithEmail(
        context,
        emailCtl.text.trim(),
        passCtl.text,
        isTherapist: isTherapist,
      );
      if (created != null) {
        // If an invitation was verified pre-auth, link and consume it now
        final pending = InvitationService.pendingInvitation;
        if (pending != null) {
          try {
            await UserService().linkPatientToTherapist(
              userId: created.id,
              therapistId: pending.therapistId,
            );
            await InvitationService().validateAndUseCode(
              code: pending.code,
              patientId: created.id,
            );
            InvitationService.pendingInvitation = null;
          } catch (e) {
            messenger.showSnackBar(
              SnackBar(content: Text('Linked account but failed to finalize code: $e')),
            );
          }
        }
        // Upload avatar if selected and update profile with name + avatar
        final storageUrl = await _uploadAvatar(created.id);
        final userService = UserService();
        await userService.updateProfile(
          userId: created.id,
          firstName: nameCtl.text.trim(),
          lastName: '',
          avatarUrl: storageUrl,
          isTherapist: isTherapist,
        );
        // Optionally update Firebase Auth profile
        final authUser = FirebaseAuth.FirebaseAuth.instance.currentUser;
        if (authUser != null) {
          await authUser.updateDisplayName(nameCtl.text.trim());
          if (storageUrl != null) {
            await authUser.updatePhotoURL(storageUrl);
          }
        }
        // Require email verification before entering the app
        final currentUser = FirebaseAuth.FirebaseAuth.instance.currentUser;
        if (currentUser != null && !currentUser.emailVerified) {
          await _authManager.sendEmailVerification(user: currentUser);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => VerifyEmailPage(
                  email: emailCtl.text.trim(),
                  isTherapist: isTherapist,
                ),
              ),
            );
          }
        } else if (mounted) {
          final email = currentUser?.email;
          if (AdminAccess.isAdminEmail(email)) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => isTherapist ? const MyPatientsPage() : const PatientOnboardingFlowPage(),
              ),
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarWidget = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : _pickAvatar,
        customBorder: const CircleBorder(),
        child: CircleAvatar(
          radius: 44,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: _avatarBytes != null
              ? MemoryImage(_avatarBytes!)
              : (_avatarPreviewUrl != null ? NetworkImage(_avatarPreviewUrl!) as ImageProvider : null),
          child: _avatarBytes == null && _avatarPreviewUrl == null
              ? Icon(Icons.person, size: 56, color: Colors.grey.shade600)
              : null,
        ),
      ),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 6),
      Center(child: avatarWidget),
      const SizedBox(height: 16),
      Text(
        'Account type',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      _buildRoleSelector(context),
      const SizedBox(height: 20),
      RoundedTextField(controller: nameCtl, hintText: 'User Name'),
      const SizedBox(height: 12),
      RoundedTextField(controller: emailCtl, hintText: 'Email Address', keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 12),
      PasswordTextField(controller: passCtl, hintText: 'Password'),
      const SizedBox(height: 16),
      PasswordTextField(controller: confirmCtl, hintText: 'Confirm Password'),
      const SizedBox(height: 12),
      TermsCheckbox(
        value: agreeTos,
        onChanged: (v) => setState(() => agreeTos = v ?? false),
        label: 'I agree to the Therapii',
        underlined: 'Terms of Service',
        onLinkTap: () => _openUrl('https://trytherapii.com/?page_id=115'),
      ),
      const SizedBox(height: 6),
      TermsCheckbox(
        value: agreePrivacy,
        onChanged: (v) => setState(() => agreePrivacy = v ?? false),
        label: 'I agree to the Therapii',
        underlined: 'Privacy Policy',
        onLinkTap: () => _openUrl('https://trytherapii.com/?page_id=3'),
      ),
      const SizedBox(height: 16),
      PrimaryButton(
        label: 'Submit',
        onPressed: _isLoading ? null : _submit,
        isLoading: _isLoading,
      ),
    ]);
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({super.key});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final emailCtl = TextEditingController();
  final passCtl = TextEditingController();
  bool agreeTos = false;
  bool agreePrivacy = true; // match screenshot
  bool _isLoading = false;
  final FirebaseAuthManager _authManager = FirebaseAuthManager();
  AccountRole? _role; // Require explicit selection; no default

  @override
  void dispose() {
    emailCtl.dispose();
    passCtl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_role == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Please select account type: Therapist or Patient.')));
      return;
    }
    if (emailCtl.text.isEmpty || passCtl.text.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Enter email and password.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await _authManager.signInWithEmail(
        context,
        emailCtl.text.trim(),
        passCtl.text,
      );

      if (user != null) {
        final selectedTherapist = _role == AccountRole.therapist;
        if (user.isTherapist != selectedTherapist) {
          final actualRole = user.isTherapist ? 'Therapist' : 'Patient';
          await _authManager.signOut();
          messenger.showSnackBar(
            SnackBar(content: Text('This account is registered as a $actualRole. Switch to the $actualRole role to continue.')),
          );
          return;
        }
        // If a pending invitation exists, finalize linking now that we are authenticated
        final pending = InvitationService.pendingInvitation;
        if (pending != null) {
          try {
            await UserService().linkPatientToTherapist(
              userId: user.id,
              therapistId: pending.therapistId,
            );
            await InvitationService().validateAndUseCode(
              code: pending.code,
              patientId: user.id,
            );
            InvitationService.pendingInvitation = null;
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to apply invitation: $e')),
            );
          }
        }
        final authUser = FirebaseAuth.FirebaseAuth.instance.currentUser;
        final requiresVerification = authUser != null && !authUser.emailVerified;

        if (requiresVerification) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => VerifyEmailPage(
                  email: emailCtl.text.trim(),
                  isTherapist: user.isTherapist,
                ),
              ),
            );
          }
          return;
        }

        if (mounted) {
          if (AdminAccess.isAdminEmail(authUser?.email)) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AdminDashboardPage()),
            );
          } else if (user.isTherapist) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MyPatientsPage()),
            );
          } else {
            final destination = user.patientOnboardingCompleted
                ? const PatientDashboardPage()
                : const PatientOnboardingFlowPage();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => destination),
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = emailCtl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email to reset your password.')),
      );
      return;
    }
    await _authManager.resetPassword(email: email, context: context);
  }

  Widget _buildRoleSelector(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final borderColor = theme.dividerColor.withValues(alpha: 0.4);

    Widget buildOption(String label, AccountRole role) {
      final selected = _role == role;
      final baseStyle = theme.textTheme.bodyMedium ?? const TextStyle();
      return Expanded(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _isLoading
                ? null
                : () {
                    setState(() => _role = role);
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected ? scheme.primary.withValues(alpha: 0.15) : scheme.surface,
                border: selected ? Border.all(color: scheme.primary, width: 1.5) : null,
              ),
              child: Center(
                child: Text(
                  label,
                  style: baseStyle.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? scheme.primary : baseStyle.color,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        children: [
          buildOption('Therapist', AccountRole.therapist),
          Container(
            width: 1.5,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: borderColor,
          ),
          buildOption('Patient', AccountRole.patient),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 6),
      Text(
        'Account type',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      _buildRoleSelector(context),
      const SizedBox(height: 20),
      RoundedTextField(controller: emailCtl, hintText: 'Email Address', keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 12),
      PasswordTextField(controller: passCtl, hintText: 'Password'),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _isLoading ? null : _forgotPassword,
          child: const Text('Forgot Password?'),
        ),
      ),
      const SizedBox(height: 16),
      PrimaryButton(
        label: 'Log in',
        onPressed: _isLoading ? null : _login,
        isLoading: _isLoading,
      ),
    ]);
  }
}
