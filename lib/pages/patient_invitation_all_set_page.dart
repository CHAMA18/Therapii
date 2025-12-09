import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:therapii/pages/patient_onboarding_flow_page.dart';
import 'package:therapii/pages/verify_email_page.dart';

class PatientInvitationAllSetPage extends StatefulWidget {
  final bool requiresEmailVerification;
  final String patientEmail;
  final String therapistId;
  final String patientFirstName;
  final String patientLastName;

  const PatientInvitationAllSetPage({
    super.key,
    required this.requiresEmailVerification,
    required this.patientEmail,
    required this.therapistId,
    required this.patientFirstName,
    required this.patientLastName,
  });

  @override
  State<PatientInvitationAllSetPage> createState() => _PatientInvitationAllSetPageState();
}

class _PatientInvitationAllSetPageState extends State<PatientInvitationAllSetPage> {
  final TextEditingController _messageCtrl = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  String? _recordedPath;
  bool _permissionDenied = false;

  @override
  void dispose() {
    _recordTimer?.cancel();
    _messageCtrl.dispose();
    if (_isRecording) {
      unawaited(_audioRecorder.stop());
    }
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  void _handleDone() {
    if (!mounted) return;

    if (widget.requiresEmailVerification) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => VerifyEmailPage(email: widget.patientEmail, isTherapist: false),
        ),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const PatientOnboardingFlowPage(),
      ),
      (route) => false,
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      _recordTimer?.cancel();
      setState(() {
        _isRecording = false;
        _recordDuration = Duration.zero;
        _recordedPath = path ?? 'voice_message';
      });
      return;
    }

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        setState(() => _permissionDenied = true);
        return;
      }

      final outputPath = await _generateRecordingPath();

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
        ),
        path: outputPath,
      );

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _recordDuration += const Duration(seconds: 1);
        });
      });

      setState(() {
        _isRecording = true;
        _permissionDenied = false;
        _recordedPath = null;
        _recordDuration = Duration.zero;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start recording: $error')),
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<String> _generateRecordingPath() async {
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    if (kIsWeb) {
      return fileName;
    }

    try {
      final directory = await getTemporaryDirectory();
      return '${directory.path}/$fileName';
    } catch (_) {
      return fileName;
    }
  }

  String _patientInitials() {
    final first = widget.patientFirstName.trim();
    final last = widget.patientLastName.trim();
    if (first.isEmpty && last.isEmpty) {
      final email = widget.patientEmail.trim();
      if (email.isEmpty) return 'YOU';
      final atIndex = email.indexOf('@');
      final source = atIndex > 0 ? email.substring(0, atIndex) : email;
      return source.isEmpty ? 'YOU' : source.substring(0, 1).toUpperCase();
    }

    final buffer = StringBuffer();
    if (first.isNotEmpty) buffer.write(first.substring(0, 1).toUpperCase());
    if (last.isNotEmpty) buffer.write(last.substring(0, 1).toUpperCase());
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseHeading = theme.textTheme.headlineMedium ??
        theme.textTheme.headlineSmall ??
        theme.textTheme.titleLarge ??
        const TextStyle(fontSize: 26, fontWeight: FontWeight.w700);
    final headingStyle = baseHeading.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: theme.colorScheme.onSurface,
    );
    final highlightStyle = headingStyle.copyWith(color: theme.colorScheme.primary);
    final subtitleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
      height: 1.4,
    );
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.85),
      height: 1.5,
    );
    final composerHintStyle = theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500);

    Widget bullet(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•', style: bodyStyle?.copyWith(fontSize: 20, height: 1.15)),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: bodyStyle)),
          ],
        ),
      );
    }

    final initials = _patientInitials();
    final isYouFallback = initials == 'YOU';

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
        title: const Text('All Set'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: headingStyle,
                      children: [
                        const TextSpan(text: 'All Set! '),
                        TextSpan(
                          text:
                              'KAI is available to talk whenever and wherever you are and about anything you want. ',
                          style: headingStyle,
                        ),
                        TextSpan(
                          text: 'We are excited to get started and get to know you better.',
                          style: highlightStyle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('A few things you should know:', style: subtitleStyle),
                  const SizedBox(height: 16),
                  bullet(
                    'KAI is not a licensed therapist and will not diagnose you or make a treatment plan. KAI will follow the guidance of your therapist.',
                  ),
                  bullet(
                    'The information you share with KAI will be shared with your real-life therapist.',
                  ),
                  bullet(
                    'The information you share with KAI will not be shared with anyone else unless required by law. We follow the same rules that apply for your interactions with your real-life therapist.',
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Text(
                              'Would you like to tell me a little about your story?',
                              style: bodyStyle?.copyWith(color: theme.colorScheme.onSurface),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageCtrl,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Enter message here...',
                              hintStyle: composerHintStyle,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? theme.colorScheme.error.withOpacity(0.12)
                                : theme.colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _toggleRecording(),
                              child: Center(
                                child: Icon(
                                  _isRecording ? Icons.stop : Icons.mic_none,
                                  size: 20,
                                  color: _isRecording ? theme.colorScheme.error : theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            isYouFallback ? initials : initials.toUpperCase(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_permissionDenied)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Microphone permission is needed to record a voice message. Please allow access and try again.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  if (_isRecording || _recordedPath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Icon(
                            _isRecording ? Icons.fiber_manual_record : Icons.play_arrow,
                            size: 16,
                            color: _isRecording ? theme.colorScheme.error : theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isRecording
                                ? 'Recording... ${_formatDuration(_recordDuration)}'
                                : 'Voice message saved',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      onPressed: _handleDone,
                      child: const Text('Done'),
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
