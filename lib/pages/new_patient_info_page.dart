import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as FirebaseAuth;
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/pages/auth_welcome_page.dart';
import 'package:therapii/pages/new_patient_confirm_page.dart';
import 'package:therapii/services/invitation_service.dart';
import 'package:therapii/models/invitation_code.dart';

class NewPatientInfoPage extends StatefulWidget {
  const NewPatientInfoPage({super.key});

  @override
  State<NewPatientInfoPage> createState() => _NewPatientInfoPageState();
}

class _NewPatientInfoPageState extends State<NewPatientInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _invitationService = InvitationService();

  bool _offerCredits = true;
  int? _selectedCredits;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.25))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
      );

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      final currentUser = FirebaseAuthManager().currentUser;
      if (currentUser == null) {
        throw Exception('Not authenticated');
      }

      // Force refresh the auth token to ensure it's valid
      await currentUser.getIdToken(true);

      // Extract first name from full name
      final fullName = _nameController.text.trim();
      final parts = fullName.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
      final firstName = parts.isNotEmpty ? parts.first : fullName;
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      // Create invitation and send email
      final createResult = await _invitationService.createInvitationAndSendEmail(
        therapistId: currentUser.uid,
        patientEmail: _emailController.text.trim(),
        patientFirstName: firstName,
        patientLastName: lastName,
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NewPatientConfirmPage(
              patientName: fullName,
              patientEmail: _emailController.text.trim(),
              invitationCode: createResult.invitation.code,
              emailSent: createResult.emailSent,
            ),
          ),
        );
      }
    } on FirebaseAuth.FirebaseAuthException catch (e) {
      if (mounted) {
        // Auth token issue - prompt user to re-authenticate
        final shouldReauth = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Session Expired'),
            content: const Text('Your session has expired. Please sign in again to continue.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sign In'),
              ),
            ],
          ),
        );

        if (shouldReauth == true && mounted) {
          await FirebaseAuthManager().signOut();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthWelcomePage(initialTab: AuthTab.login)),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        // Check if error message contains auth-related keywords
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('authorization') || 
            errorMsg.contains('unauthenticated') || 
            errorMsg.contains('expired') ||
            errorMsg.contains('revoked') ||
            errorMsg.contains('invalid')) {
          // Auth issue - prompt to re-authenticate
          final shouldReauth = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Session Expired'),
              content: const Text('Your session has expired. Please sign in again to continue.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Sign In'),
                ),
              ],
            ),
          );

          if (shouldReauth == true && mounted) {
            await FirebaseAuthManager().signOut();
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthWelcomePage(initialTab: AuthTab.login)),
                (route) => false,
              );
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send invitation: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

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
        title: const Text('Invite Patient'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top bar
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Image.asset('assets/images/therapii_logo.png'),
                            ),
                          ),
                          const Spacer(),
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
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('New Patient Info', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        'Please enter the information int he form then hit submit',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: _fieldDecoration("Patient's Full Name"),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              decoration: _fieldDecoration('Patient Email'),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Offer free credits. Each credit is worth one free month',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Switch(
                                  value: _offerCredits,
                                  activeColor: Colors.white,
                                  activeTrackColor: primary,
                                  onChanged: (v) => setState(() => _offerCredits = v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<int>(
                              value: _selectedCredits,
                              items: [1, 2, 3, 4, 5].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                              onChanged: _offerCredits ? (v) => setState(() => _selectedCredits = v) : null,
                              decoration: _fieldDecoration('Select...'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _notesController,
                              minLines: 5,
                              maxLines: 6,
                              decoration: _fieldDecoration(
                                "Let's personalize the AI's approach! Please provide some key information about this patient so the AI can tailor its style and make the session feel more personal.",
                              ).copyWith(hintMaxLines: 5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'By clicking Submit, you authorize Therapii to send an email invitation to establish an Therapii account.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3F62A8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
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
