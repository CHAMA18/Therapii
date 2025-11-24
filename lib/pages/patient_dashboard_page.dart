import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/models/invitation_code.dart';
import 'package:therapii/models/user.dart' as app_user;
import 'package:therapii/pages/ai_therapist_chat_page.dart';
import 'package:therapii/pages/auth_welcome_page.dart';
import 'package:therapii/pages/patient_chat_page.dart';
import 'package:therapii/pages/patient_voice_conversation_page.dart';
import 'package:therapii/services/chat_service.dart';
import 'package:therapii/services/invitation_service.dart';
import 'package:therapii/services/user_service.dart';

class PatientDashboardPage extends StatefulWidget {
  final String? therapistId;

  const PatientDashboardPage({super.key, this.therapistId});

  @override
  State<PatientDashboardPage> createState() => _PatientDashboardPageState();
}

class _PatientDashboardPageState extends State<PatientDashboardPage> {
  final FirebaseAuthManager _authManager = FirebaseAuthManager();
  final UserService _userService = UserService();
  final InvitationService _invitationService = InvitationService();
  final ChatService _chatService = ChatService();

  app_user.User? _patient;
  app_user.User? _therapistUser;
  bool _loading = true;
  bool _processingCode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      setState(() {
        _error = 'You need to be signed in to continue.';
        _loading = false;
      });
      return;
    }

    try {
      final patient = await _userService.getUser(firebaseUser.uid);
      if (!mounted) return;

      if (patient == null) {
        setState(() {
          _error = 'We were unable to load your profile.';
          _loading = false;
        });
        return;
      }

      final therapistId = (widget.therapistId?.trim().isNotEmpty ?? false)
          ? widget.therapistId!.trim()
          : (patient.therapistId?.trim().isNotEmpty ?? false)
              ? patient.therapistId!.trim()
              : null;

      setState(() {
        _patient = patient;
      });

      await _loadTherapist(therapistId);
      if (!mounted) return;

      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while loading your dashboard. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _loadTherapist(String? therapistId) async {
    if (!mounted) return;

    if (therapistId == null || therapistId.isEmpty) {
      setState(() => _therapistUser = null);
      return;
    }

    try {
      final therapist = await _userService.getUser(therapistId);
      if (!mounted) return;
      setState(() => _therapistUser = therapist);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load therapist details: $error')),
      );
    }
  }

  Future<void> _promptForInvitationCode() async {
    if (_processingCode) return;
    final patient = _patient;
    if (patient == null) return;

    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final theme = Theme.of(context);

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Enter Invitation Code',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              maxLength: 5,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                counterText: '',
                hintText: '5-digit code',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'Enter the code shared by your therapist';
                }
                if (!RegExp(r'^\d{5}$').hasMatch(text)) {
                  return 'Code must be 5 digits';
                }
                return null;
              },
              onChanged: (value) {
                final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
                if (digitsOnly != value) {
                  controller.value = TextEditingValue(
                    text: digitsOnly,
                    selection: TextSelection.collapsed(offset: digitsOnly.length),
                  );
                }
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) {
      controller.dispose();
      return;
    }

    setState(() => _processingCode = true);

    try {
      final InvitationCode? invitation = await _invitationService.validateAndUseCode(
        code: result,
        patientId: patient.id,
      );

      if (invitation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid or expired code. Please double-check with your therapist.')),
          );
        }
        return;
      }

      await _userService.linkPatientToTherapist(
        userId: patient.id,
        therapistId: invitation.therapistId,
      );

      await _chatService.ensureConversation(
        therapistId: invitation.therapistId,
        patientId: patient.id,
      );

      final therapistUser = await _userService.getUser(invitation.therapistId);

      if (!mounted) return;

      setState(() {
        _therapistUser = therapistUser;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are now connected to ${therapistUser?.fullName ?? 'your therapist'}!'),
        ),
      );

      if (therapistUser != null) {
        _openChat(therapistUser);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to verify your code: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _processingCode = false);
      }
    }

    controller.dispose();
  }

  void _openChat(app_user.User otherUser) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PatientChatPage(otherUser: otherUser)),
    );
  }

  void _openAiTherapist() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiTherapistChatPage()),
    );
  }

  void _openVoiceRecording(app_user.User therapist) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PatientVoiceConversationPage(therapist: therapist)),
    );
  }

  Future<void> _handleMessageTap(app_user.User therapist) async {
    final patient = _patient;
    if (patient == null) return;

    try {
      await _chatService.ensureConversation(
        therapistId: therapist.id,
        patientId: patient.id,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open therapist messages: $error')),
      );
      return;
    }

    if (!mounted) return;
    _openChat(therapist);
  }

  void _showTherapistRequiredSnack() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Add your therapist to access this feature.'),
        action: SnackBarAction(
          label: 'Enter code',
          onPressed: () {
            messenger.hideCurrentSnackBar();
            _promptForInvitationCode();
          },
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await _authManager.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthWelcomePage(initialTab: AuthTab.login)),
      (route) => false,
    );
  }

  String _resolvePatientDisplayName() {
    final patient = _patient;
    if (patient == null) {
      return 'there';
    }
    if (patient.firstName.trim().isNotEmpty) {
      return patient.firstName.trim();
    }
    final emailPrefix = patient.email.split('@').first;
    return emailPrefix.trim().isEmpty ? 'there' : emailPrefix;
  }

  String _resolveTherapistEmail() {
    final therapist = _therapistUser;
    return therapist?.email ?? 'your therapist';
  }

  String _resolveAiHandle() => 'KAI';

  Widget _buildErrorState(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.redAccent, height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _initialize,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return _buildErrorState(context);
    }

    final displayName = _resolvePatientDisplayName();
    final aiHandle = _resolveAiHandle();
    final therapistEmail = _resolveTherapistEmail();

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 720;
          final horizontalPadding = isCompact ? 24.0 : 64.0;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isCompact ? 24 : 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Patient > Listen (Home)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            letterSpacing: 0.15,
                          ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _signOut,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                        textStyle: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Logout'),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment:
                            isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, $displayName!',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                            textAlign: isCompact ? TextAlign.center : TextAlign.start,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'How would you like to engage with Therapii today?',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                            textAlign: isCompact ? TextAlign.center : TextAlign.start,
                          ),
                          const SizedBox(height: 36),
                          Wrap(
                            spacing: 24,
                            runSpacing: 24,
                            alignment: isCompact ? WrapAlignment.center : WrapAlignment.start,
                            children: [
                              _DashboardActionCard(
                                label: 'Chat with $aiHandle',
                                onTap: _openAiTherapist,
                              ),
                              _DashboardActionCard(
                                label: 'Message $therapistEmail',
                                onTap: _therapistUser == null
                                    ? _showTherapistRequiredSnack
                                    : () => _handleMessageTap(_therapistUser!),
                                muted: _therapistUser == null,
                              ),
                              _DashboardActionCard(
                                label: 'Listen with $therapistEmail',
                                icon: Icons.mic_none_rounded,
                                onTap: _therapistUser == null
                                    ? _showTherapistRequiredSnack
                                    : () => _openVoiceRecording(_therapistUser!),
                                muted: _therapistUser == null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildContent(context),
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool muted;

  const _DashboardActionCard({
    required this.label,
    required this.onTap,
    this.icon,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = muted ? const Color(0xFFE8E8E8) : const Color(0xFFD9D9D9);
    final textColor = muted ? Colors.black54 : Colors.black87;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.black.withOpacity(0.08),
        highlightColor: Colors.black.withOpacity(0.04),
        child: Container(
          width: 180,
          height: 140,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColor, size: 32),
                const SizedBox(height: 12),
              ],
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}