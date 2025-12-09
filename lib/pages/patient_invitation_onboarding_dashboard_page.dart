import 'package:flutter/material.dart';
import 'package:therapii/models/therapist.dart';
import 'package:therapii/models/user.dart' as app_user;
import 'package:therapii/pages/patient_chat_page.dart';
import 'package:therapii/pages/verify_email_page.dart';
import 'package:therapii/services/therapist_service.dart';
import 'package:therapii/services/user_service.dart';

class PatientInvitationOnboardingDashboardPage extends StatefulWidget {
  final String therapistId;
  final String patientEmail;
  final bool requiresEmailVerification;
  final String patientFirstName;
  final String patientLastName;

  const PatientInvitationOnboardingDashboardPage({
    super.key,
    required this.therapistId,
    required this.patientEmail,
    required this.requiresEmailVerification,
    required this.patientFirstName,
    required this.patientLastName,
  });

  @override
  State<PatientInvitationOnboardingDashboardPage> createState() => _PatientInvitationOnboardingDashboardPageState();
}

class _PatientInvitationOnboardingDashboardPageState extends State<PatientInvitationOnboardingDashboardPage> {
  final TherapistService _therapistService = TherapistService();
  final UserService _userService = UserService();

  bool _loading = true;
  String? _error;
  Therapist? _therapist;
  app_user.User? _therapistUser;
  bool _showSummary = false;

  @override
  void initState() {
    super.initState();
    _loadTherapist();
  }

  Future<void> _loadTherapist() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final therapist = await _therapistService.getTherapist(widget.therapistId);
      app_user.User? therapistUser;
      if (therapist != null) {
        therapistUser = await _userService.getUser(therapist.userId);
      }

      if (!mounted) return;
      setState(() {
        _therapist = therapist;
        _therapistUser = therapistUser;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load your therapist at the moment. Please try again shortly.';
        _loading = false;
      });
    }
  }

  void _openVerifyEmail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerifyEmailPage(email: widget.patientEmail, isTherapist: false),
      ),
    );
  }

  void _openTherapistChat() {
    final therapistUser = _therapistUser;
    if (therapistUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not find your therapist profile just yet. Please try again.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PatientChatPage(otherUser: therapistUser)),
    );
  }

  void _openAiTherapist() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('KAI conversations are coming soon. Stay tuned!')),
    );
  }

  String get _patientGreetingName {
    final first = widget.patientFirstName.trim();
    final last = widget.patientLastName.trim();
    if (first.isEmpty && last.isEmpty) {
      final email = widget.patientEmail.trim();
      if (email.isEmpty) return 'there';
      final atIndex = email.indexOf('@');
      return atIndex > 0 ? email.substring(0, atIndex) : email;
    }
    return [first, last].where((part) => part.isNotEmpty).join(' ');
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary.withOpacity(0.12), scheme.primary.withOpacity(0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: scheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${_patientGreetingName.isEmpty ? 'there' : _patientGreetingName}!',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'You are now connected to your therapist and ready to start sharing. Use the quick actions below to jump in.',
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurface.withOpacity(0.75), height: 1.5),
          ),
          if (widget.requiresEmailVerification) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.mark_email_unread, color: scheme.secondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verify your email to unlock all features.',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'We sent a verification link to ${widget.patientEmail}. Tap below once you have verified it.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.7)),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                            onPressed: _openVerifyEmail,
                            child: const Text('Open verification steps'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTherapistCard(BuildContext context) {
    final therapist = _therapist;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (therapist == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: scheme.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.error.withOpacity(0.2)),
        ),
        child: Text('We could not load your therapist just yet. Please refresh in a moment.', style: theme.textTheme.bodyLarge?.copyWith(color: scheme.error)),
      );
    }

    final profileImage = therapist.profileImageUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 16, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFFE9EAED),
                backgroundImage: profileImage != null && profileImage.isNotEmpty ? NetworkImage(profileImage) : null,
                child: (profileImage == null || profileImage.isEmpty)
                    ? const Icon(Icons.person_outline, size: 32, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(therapist.fullName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      therapist.specialization.isNotEmpty ? therapist.specialization : 'Licensed Therapist',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                    ),
                    if (therapist.rating > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text('${therapist.rating.toStringAsFixed(1)} average rating', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            therapist.bio.isNotEmpty
                ? therapist.bio
                : 'Your therapist will add a bio soon. In the meantime, feel free to introduce yourself using the actions below.',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget actionCard({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, Color? color}) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outline.withOpacity(0.08)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 14, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (color ?? scheme.primary).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color ?? scheme.primary, size: 22),
                ),
                const SizedBox(height: 18),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface)),
                const SizedBox(height: 6),
                Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.7))),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 640;
        final talkAi = actionCard(
          icon: Icons.auto_awesome,
          title: 'Talk to KAI',
          subtitle: 'Get instant responses 24/7 guided by your care team.',
          onTap: _openAiTherapist,
        );
        final talkTherapist = actionCard(
          icon: Icons.chat_bubble_outline,
          title: 'Talk to Assigned Therapist',
          subtitle: 'Send a direct message or schedule your next session.',
          onTap: _openTherapistChat,
          color: scheme.secondary,
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: talkAi),
              const SizedBox(width: 20),
              Expanded(child: talkTherapist),
            ],
          );
        }

        return Column(
          children: [
            talkAi,
            const SizedBox(height: 20),
            talkTherapist,
          ],
        );
      },
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 14, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Conversation summaries',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
                ),
              ),
              Switch(
                value: _showSummary,
                onChanged: (value) => setState(() => _showSummary = value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enable to see quick recaps of your latest sessions with highlights prepared for you and your therapist.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.7)),
          ),
          AnimatedCrossFade(
            crossFadeState: _showSummary ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.summarize, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text('Latest summary', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We will capture the key points from your AI and therapist conversations here so you always know what to focus on next.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start a conversation to generate your first summary.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListenSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline.withOpacity(0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 14, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.headphones, color: scheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Listen in', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Review AI conversation transcripts so you and your therapist stay aligned.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Listening micro-summaries will appear once conversations begin.')),
                  );
                },
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('Open listen view'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'New summaries and audio recaps from your AI sessions will live here. You will be notified once they are ready.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.7), height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text('Therapii Overview', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error)),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _loadTherapist,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(context),
                            const SizedBox(height: 24),
                            _buildTherapistCard(context),
                            const SizedBox(height: 24),
                            _buildQuickActions(context),
                            const SizedBox(height: 24),
                            _buildSummarySection(context),
                            const SizedBox(height: 24),
                            _buildListenSection(context),
                            const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}