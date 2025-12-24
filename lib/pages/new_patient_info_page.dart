import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as FirebaseAuth;
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/pages/auth_welcome_page.dart';
import 'package:therapii/pages/new_patient_confirm_page.dart';
import 'package:therapii/services/invitation_service.dart';

class NewPatientInfoPage extends StatefulWidget {
  const NewPatientInfoPage({super.key});

  @override
  State<NewPatientInfoPage> createState() => _NewPatientInfoPageState();
}

class _NewPatientInfoPageState extends State<NewPatientInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _therapyLengthController = TextEditingController();
  final _diagnosesController = TextEditingController();
  final _safetyNotesController = TextEditingController();
  final _responseController = TextEditingController();
  final _focusController = TextEditingController();
  final _invitationService = InvitationService();

  bool _offerCredits = true;
  int? _selectedCredits;
  bool _isSubmitting = false;
  String _engagementStyle = 'suggestions';
  bool _flagSuicidal = false;
  bool _flagSelfHarm = false;
  bool _flagThreats = false;
  bool _flagViolence = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _therapyLengthController.dispose();
    _diagnosesController.dispose();
    _safetyNotesController.dispose();
    _responseController.dispose();
    _focusController.dispose();
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

  Widget _questionCard({required Widget child}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );

  Map<String, dynamic> _buildPatientBackgroundPayload() {
    Map<String, dynamic> cleanMap(Map<String, dynamic> input) {
      final map = <String, dynamic>{};
      input.forEach((key, value) {
        if (value == null) return;
        if (value is String) {
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) map[key] = trimmed;
        } else if (value is Map) {
          final child = cleanMap(value.cast<String, dynamic>());
          if (child.isNotEmpty) map[key] = child;
        } else {
          map[key] = value;
        }
      });
      return map;
    }

    final background = cleanMap({
      'engagementStyle': _engagementStyle,
      'therapyLength': _therapyLengthController.text,
      'diagnoses': _diagnosesController.text,
      'therapyResponse': _responseController.text,
      'focusAreas': _focusController.text,
      'safety': {
        'suicidalIdeation': _flagSuicidal,
        'selfHarm': _flagSelfHarm,
        'threatsToOthers': _flagThreats,
        'actualViolence': _flagViolence,
        'notes': _safetyNotesController.text,
      },
    });

    final safety = background['safety'];
    if (safety is Map && safety.values.every((value) => value == false || value == null)) {
      background.remove('safety');
    }

    return background;
  }

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
        patientBackground: _buildPatientBackgroundPayload(),
      );

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NewPatientConfirmPage(
              patientName: fullName,
              patientEmail: _emailController.text.trim(),
              invitationCode: createResult.invitation.code,
              emailSent: createResult.emailSent,
              emailWarning: createResult.emailWarning,
            ),
          ),
        );
      }
    } on FirebaseAuth.FirebaseAuthException {
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
                                  thumbColor: MaterialStateProperty.resolveWith((states) {
                                    if (states.contains(MaterialState.selected)) return Colors.white;
                                    return null;
                                  }),
                                  trackColor: MaterialStateProperty.resolveWith((states) {
                                    if (states.contains(MaterialState.selected)) return primary;
                                    return null;
                                  }),
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
                            const SizedBox(height: 4),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _nameController,
                              builder: (_, value, __) {
                                final name = value.text.trim().isEmpty ? 'this patient' : value.text.trim();
                                return Text('About $name', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700));
                              },
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Answer a few questions so the Therapii agent can personalize care for this patient.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 12),
                            _questionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('1. How would you like the Therapii agent to engage with this patient?', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  ...const [
                                    {'value': 'suggestions', 'label': 'Make suggestions and guide the session'},
                                    {'value': 'solicit', 'label': 'Actively solicit information'},
                                    {'value': 'blend', 'label': 'Ask questions and make suggestions'},
                                  ].map((option) => RadioListTile<String>(
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        value: option['value']!,
                                        groupValue: _engagementStyle,
                                        title: Text(option['label']!),
                                        onChanged: (val) => setState(() => _engagementStyle = val ?? _engagementStyle),
                                      )),
                                ],
                              ),
                            ),
                            _questionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '2. How long have you been working with this patient and how much longer do you expect to be treating them? If they have other therapists, share that too.',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _therapyLengthController,
                                    minLines: 2,
                                    maxLines: 4,
                                    decoration: _fieldDecoration('Share any timeline context'),
                                  ),
                                ],
                              ),
                            ),
                            _questionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '3. What diagnoses have you or others made, and what symptoms should we know about? (Include health factors that are not specifically mental health.)',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _diagnosesController,
                                    minLines: 2,
                                    maxLines: 4,
                                    decoration: _fieldDecoration('Diagnoses, symptoms, or health factors'),
                                  ),
                                ],
                              ),
                            ),
                            _questionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '4. Safety is my first priority. Flag anything you want the agent to watch for.',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 6,
                                    children: [
                                      FilterChip(
                                        label: const Text('Suicidal thoughts or ideation'),
                                        selected: _flagSuicidal,
                                        onSelected: (v) => setState(() => _flagSuicidal = v),
                                      ),
                                      FilterChip(
                                        label: const Text('Self harm'),
                                        selected: _flagSelfHarm,
                                        onSelected: (v) => setState(() => _flagSelfHarm = v),
                                      ),
                                      FilterChip(
                                        label: const Text('Threats of violence to others'),
                                        selected: _flagThreats,
                                        onSelected: (v) => setState(() => _flagThreats = v),
                                      ),
                                      FilterChip(
                                        label: const Text('Actual violence toward others'),
                                        selected: _flagViolence,
                                        onSelected: (v) => setState(() => _flagViolence = v),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _safetyNotesController,
                                    minLines: 2,
                                    maxLines: 4,
                                    decoration: _fieldDecoration('Add safety context or instructions'),
                                  ),
                                ],
                              ),
                            ),
                            _questionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '5. How are they responding to therapy? What seems to be working and what has not?',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _responseController,
                                    minLines: 2,
                                    maxLines: 4,
                                    decoration: _fieldDecoration('Share what is or is not effective'),
                                  ),
                                ],
                              ),
                            ),
                            _questionCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '6. Are there things you want the agent to listen for or focus on with this patient?',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _focusController,
                                    minLines: 2,
                                    maxLines: 4,
                                    decoration: _fieldDecoration('Goals, triggers, preferences, or requests'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
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
