import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_fonts/google_fonts.dart';

import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/models/invitation_code.dart';
import 'package:therapii/models/user.dart' as app_user;
import 'package:therapii/pages/ai_therapist_chat_page.dart';
import 'package:therapii/pages/auth_welcome_page.dart';
import 'package:therapii/pages/billing_page.dart';
import 'package:therapii/pages/patient_chat_page.dart';
import 'package:therapii/pages/patient_voice_conversation_page.dart';
import 'package:therapii/pages/support_center_page.dart';
import 'package:therapii/services/chat_service.dart';
import 'package:therapii/services/invitation_service.dart';
import 'package:therapii/services/user_service.dart';
import 'package:therapii/theme.dart';
import 'package:therapii/widgets/common_settings_drawer.dart';
import 'package:therapii/widgets/dashboard_action_card.dart';

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
  String? _therapistAiName;
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
      setState(() {
        _therapistUser = null;
        _therapistAiName = null;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(therapistId).get();
      if (!mounted) return;
      if (!doc.exists) {
        setState(() {
          _therapistUser = null;
          _therapistAiName = null;
        });
        return;
      }
      final therapist = app_user.User.fromJson(doc.data()!);
      
      // Load AI name from therapist's training profile
      String? aiName;
      try {
        final therapistDoc = await FirebaseFirestore.instance.collection('therapists').doc(therapistId).get();
        if (therapistDoc.exists) {
          final therapistData = therapistDoc.data();
          final aiProfile = therapistData?['ai_training_profile'];
          if (aiProfile is Map<String, dynamic>) {
            final name = aiProfile['name'];
            if (name is String && name.isNotEmpty) {
              aiName = name;
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to load AI name: $e');
      }
      
      setState(() {
        _therapistUser = therapist;
        _therapistAiName = aiName;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _therapistUser = null;
        _therapistAiName = null;
      });
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

  String _resolveAiHandle() {
    // Return custom AI name if available, otherwise default to 'KAI'
    return _therapistAiName ?? 'KAI';
  }

  Widget _buildErrorState(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.error, height: 1.4),
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
    final theme = Theme.of(context);
    
    // Greeting logic
    final hour = DateTime.now().hour;
    String greeting = 'Hello';
    if (hour < 12) {
      greeting = 'Good morning';
    } else if (hour < 17) {
      greeting = 'Good afternoon';
    } else {
      greeting = 'Good evening';
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section with Avatar
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 40),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting + ',',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            displayName,
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'How are you feeling today?',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_patient?.avatarUrl != null)
                      CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(_patient!.avatarUrl!),
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      )
                    else
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Action Cards Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isWide = width > 600;

                  if (!isWide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DashboardActionCard(
                          title: 'Chat with $aiHandle',
                          subtitle: 'Your 24/7 AI companion',
                          icon: Icons.auto_awesome_rounded,
                          isPrimary: true,
                          onTap: _openAiTherapist,
                        ),
                        const SizedBox(height: 20),
                        DashboardActionCard(
                          title: 'Message Therapist',
                          subtitle: _therapistUser != null ? 'Connected with ${_therapistUser!.firstName}' : 'Connect with your therapist',
                          icon: Icons.chat_bubble_outline_rounded,
                          onTap: _therapistUser == null
                              ? _showTherapistRequiredSnack
                              : () => _handleMessageTap(_therapistUser!),
                          isDisabled: _therapistUser == null,
                          isSecondary: true,
                          actionLabel: _therapistUser == null ? 'Connect' : null,
                        ),
                        const SizedBox(height: 20),
                        DashboardActionCard(
                          title: 'Voice Session',
                          subtitle: 'Record and share your thoughts',
                          icon: Icons.mic_rounded,
                          onTap: _therapistUser == null
                              ? _showTherapistRequiredSnack
                              : () => _openVoiceRecording(_therapistUser!),
                          isDisabled: _therapistUser == null,
                          actionLabel: _therapistUser == null ? 'Connect' : null,
                        ),
                        const SizedBox(height: 20),
                        DashboardActionCard(
                          title: 'Billing',
                          subtitle: 'Manage subscription and invoices',
                          icon: Icons.credit_card_rounded,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillingPage())),
                        ),
                        const SizedBox(height: 20),
                        DashboardActionCard(
                          title: 'Support Center',
                          subtitle: 'FAQs and help resources',
                          icon: Icons.help_outline_rounded,
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportCenterPage())),
                        ),
                      ],
                    );
                  }

                  // Tablet/Desktop Layout
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DashboardActionCard(
                              title: 'Chat with $aiHandle',
                              subtitle: 'Your 24/7 AI companion',
                              icon: Icons.auto_awesome_rounded,
                              isPrimary: true,
                              onTap: _openAiTherapist,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: DashboardActionCard(
                              title: 'Message Therapist',
                              subtitle: _therapistUser != null ? 'Connected with ${_therapistUser!.firstName}' : 'Connect with your therapist',
                              icon: Icons.chat_bubble_outline_rounded,
                              onTap: _therapistUser == null
                                  ? _showTherapistRequiredSnack
                                  : () => _handleMessageTap(_therapistUser!),
                              isDisabled: _therapistUser == null,
                              isSecondary: true,
                              actionLabel: _therapistUser == null ? 'Connect' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      DashboardActionCard(
                        title: 'Voice Session',
                        subtitle: 'Record and share your thoughts',
                        icon: Icons.mic_rounded,
                        onTap: _therapistUser == null
                            ? _showTherapistRequiredSnack
                            : () => _openVoiceRecording(_therapistUser!),
                        isDisabled: _therapistUser == null,
                        actionLabel: _therapistUser == null ? 'Connect' : null,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DashboardActionCard(
                              title: 'Billing',
                              subtitle: 'Manage subscription and invoices',
                              icon: Icons.credit_card_rounded,
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BillingPage())),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: DashboardActionCard(
                              title: 'Support Center',
                              subtitle: 'FAQs and help resources',
                              icon: Icons.help_outline_rounded,
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportCenterPage())),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
              ),
              
              const SizedBox(height: 48),
              
              // Inspirational / Info Card
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.format_quote_rounded,
                        color: theme.colorScheme.tertiary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Thought',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '"The only way out is through."',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      drawer: const CommonSettingsDrawer(),
      body: _buildContent(context),
    );
  }
}

// Action card moved to lib/widgets/dashboard_action_card.dart
