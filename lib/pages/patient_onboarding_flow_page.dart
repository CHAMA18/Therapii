import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:therapii/pages/patient_dashboard_page.dart';
import 'package:therapii/services/user_service.dart';
import 'package:therapii/widgets/primary_button.dart';

class PatientOnboardingFlowPage extends StatefulWidget {
  const PatientOnboardingFlowPage({super.key});

  @override
  State<PatientOnboardingFlowPage> createState() => _PatientOnboardingFlowPageState();
}

class _PatientOnboardingFlowPageState extends State<PatientOnboardingFlowPage> {
  final _userService = UserService();
  final _goalsCtrl = TextEditingController();
  final _supportCtrl = TextEditingController();
  final _shareAnythingCtrl = TextEditingController();

  int _stepIndex = 0;
  bool _saving = false;
  bool _initializing = true;
  String? _error;

  final Set<String> _focusAreas = <String>{};
  String _checkInFrequency = 'A few times a week';
  bool _sendReminders = true;
  bool _shareSummariesWithTherapist = true;

  static const _availableFocusAreas = <String>{
    'Managing stress',
    'Improving sleep',
    'Building confidence',
    'Navigating relationships',
    'Processing grief',
    'Motivation & habits',
  };

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _goalsCtrl.dispose();
    _supportCtrl.dispose();
    _shareAnythingCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      setState(() {
        _error = 'You need to be signed in to continue.';
        _initializing = false;
      });
      return;
    }

    try {
      final profile = await _userService.getUser(firebaseUser.uid);
      if (!mounted) return;

      if (profile?.patientOnboardingCompleted == true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PatientDashboardPage()),
            (route) => false,
          );
        });
        return;
      }

      final data = profile?.patientOnboardingData ?? <String, dynamic>{};
      if (data.isNotEmpty) {
        final goals = data['therapy_goals'];
        final focusList = data['focus_areas'];
        final support = data['support_needs'];
        final frequency = data['check_in_frequency'];
        final reminders = data['send_reminders'];
        final shareSummaries = data['share_summaries_with_therapist'];

        if (goals is String) _goalsCtrl.text = goals;
        if (support is String) _supportCtrl.text = support;
        if (frequency is String && frequency.isNotEmpty) _checkInFrequency = frequency;
        if (reminders is bool) _sendReminders = reminders;
        if (shareSummaries is bool) _shareSummariesWithTherapist = shareSummaries;
        if (focusList is List) {
          _focusAreas
            ..clear()
            ..addAll(focusList.whereType<String>());
        }

        final freeWrite = data['anything_else'];
        if (freeWrite is String) _shareAnythingCtrl.text = freeWrite;
      }

      setState(() {
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load your profile. Please try again.';
        _initializing = false;
      });
    }
  }

  double get _progress => (_stepIndex + 1) / 3;

  void _nextStep() {
    if (_stepIndex >= 2) {
      _saveAndFinish();
      return;
    }
    setState(() => _stepIndex++);
  }

  void _previousStep() {
    if (_stepIndex == 0 || _saving) return;
    setState(() => _stepIndex--);
  }

  Future<void> _saveAndFinish() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are not signed in. Please log in again.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'therapy_goals': _goalsCtrl.text.trim(),
        'focus_areas': _focusAreas.toList(),
        'support_needs': _supportCtrl.text.trim(),
        'check_in_frequency': _checkInFrequency,
        'send_reminders': _sendReminders,
        'share_summaries_with_therapist': _shareSummariesWithTherapist,
        'anything_else': _shareAnythingCtrl.text.trim(),
        'saved_at': DateTime.now().toIso8601String(),
      };

      await _userService.savePatientOnboardingData(
        userId: firebaseUser.uid,
        data: payload,
        completed: true,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PatientDashboardPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save your onboarding details: $e')),
      );
      setState(() => _saving = false);
    }
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Step ${_stepIndex + 1} of 3',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.4),
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent(BuildContext context) {
    switch (_stepIndex) {
      case 0:
        return _StepContainer(
          title: 'Let’s get to know you',
          subtitle: 'Share what brings you to Therapii so conversations can meet you where you are.',
          children: [
            TextField(
              controller: _goalsCtrl,
              minLines: 4,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: _textFieldDecoration(context, 'What would you like support with right now?'),
            ),
            const SizedBox(height: 16),
            Text(
              'Select the areas you want to focus on:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableFocusAreas.map((option) {
                final selected = _focusAreas.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _focusAreas.add(option);
                      } else {
                        _focusAreas.remove(option);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        );
      case 1:
        return _StepContainer(
          title: 'Tell us about support that helps',
          subtitle: 'Preferences help both your therapist and the AI respond in ways that feel useful.',
          children: [
            DropdownButtonFormField<String>(
              value: _checkInFrequency,
              items: const [
                'Daily check-ins',
                'A few times a week',
                'Weekly summaries',
                'Only when something important happens',
              ].map((option) => DropdownMenuItem(value: option, child: Text(option))).toList(),
              onChanged: _saving ? null : (value) => setState(() => _checkInFrequency = value ?? _checkInFrequency),
              decoration: _inputDecoration(context, 'How often would you like check-ins?'),
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: _sendReminders,
              onChanged: _saving ? null : (value) => setState(() => _sendReminders = value),
              title: const Text('Send me gentle reminders if I go quiet'),
            ),
            SwitchListTile.adaptive(
              value: _shareSummariesWithTherapist,
              onChanged: _saving ? null : (value) => setState(() => _shareSummariesWithTherapist = value),
              title: const Text('Share conversation summaries with my therapist'),
            ),
          ],
        );
      default:
        return _StepContainer(
          title: 'Anything else we should know?',
          subtitle: 'Add personal notes, routines, or boundaries so your conversations stay supportive.',
          children: [
            TextField(
              controller: _supportCtrl,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: _textFieldDecoration(context, 'What helps you feel supported on tough days?'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _shareAnythingCtrl,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: _textFieldDecoration(context, 'Anything else you want to share with us?'),
            ),
          ],
        );
    }
  }

  InputDecoration _textFieldDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_initializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadExistingData,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Therapii',
                    style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'We’ll ask a few quick questions to personalize your space. You can always update these later in settings.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.75), height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  _buildProgressIndicator(context),
                  const SizedBox(height: 24),
                  _buildStepContent(context),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      if (_stepIndex > 0)
                        TextButton(
                          onPressed: _saving ? null : _previousStep,
                          child: const Text('Back'),
                        )
                      else
                        const SizedBox.shrink(),
                      const Spacer(),
                      SizedBox(
                        width: 160,
                        child: PrimaryButton(
                          label: _stepIndex == 2 ? 'Finish' : 'Next',
                          onPressed: _saving ? null : _nextStep,
                          isLoading: _saving,
                          uppercase: false,
                        ),
                      ),
                    ],
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

class _StepContainer extends StatelessWidget {
  const _StepContainer({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.72), height: 1.5)),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}