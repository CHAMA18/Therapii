import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/services/voice_checkin_service.dart';
import 'package:therapii/models/user.dart' as app_user;
import 'package:therapii/pages/patient_chat_page.dart';

class PatientVoiceConversationPage extends StatefulWidget {
  final app_user.User therapist;
  const PatientVoiceConversationPage({super.key, required this.therapist});

  @override
  State<PatientVoiceConversationPage> createState() => _PatientVoiceConversationPageState();
}

class _PatientVoiceConversationPageState extends State<PatientVoiceConversationPage> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _permissionDenied = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String? _recordedPath;
  bool _uploading = false;

  @override
  void dispose() {
    _timer?.cancel();
    if (_isRecording) {
      unawaited(_recorder.stop());
    }
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<String> _recordPath() async {
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    if (kIsWeb) return fileName;
    try {
      final dir = await getTemporaryDirectory();
      return '${dir.path}/$fileName';
    } catch (_) {
      return fileName;
    }
  }

  String _format(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      _timer?.cancel();
      setState(() {
        _isRecording = false;
        _recordedPath = path ?? 'voice_message';
      });
      return;
    }

    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        setState(() => _permissionDenied = true);
        return;
      }
      final path = await _recordPath();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
        ),
        path: path,
      );
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _elapsed += const Duration(seconds: 1));
      });
      setState(() {
        _permissionDenied = false;
        _isRecording = true;
        _elapsed = Duration.zero;
        _recordedPath = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to access microphone: $e')));
    }
  }

  Future<void> _shareRecording() async {
    if (_recordedPath == null) return;
    final me = FirebaseAuthManager().currentUser;
    if (me == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to share.')));
      return;
    }
    setState(() => _uploading = true);
    try {
      // Upload and share with therapist
      final svc = VoiceCheckinService();
      await svc.uploadAndShareRecording(
        localPath: _recordedPath!,
        patientId: me.uid,
        therapistId: widget.therapist.id,
        durationSeconds: _elapsed.inSeconds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording shared with your therapist.')),
      );
      setState(() {
        _recordedPath = null;
        _elapsed = Duration.zero;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share recording: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PatientChatPage(otherUser: widget.therapist)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final therapistName = widget.therapist.fullName.isNotEmpty ? widget.therapist.fullName : widget.therapist.email;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Recorded Conversation'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              height: 42,
                              width: 42,
                              decoration: BoxDecoration(
                                color: scheme.primary.withValues(alpha: 0.10),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.person_outline, color: scheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Voice updates for $therapistName',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Hold a short recorded check-in. You can send a text follow-up in chat after.',
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _isRecording ? 'Recording...' : (_recordedPath == null ? 'Ready to record' : 'Recorded clip ready'),
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _format(_elapsed),
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w800,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: Material(
                                  color: _isRecording ? scheme.error.withValues(alpha: 0.12) : scheme.primary.withValues(alpha: 0.12),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _toggleRecording,
                                    child: Center(
                                      child: Icon(
                                        _isRecording ? Icons.stop : Icons.mic,
                                        color: _isRecording ? scheme.error : scheme.primary,
                                        size: 42,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_permissionDenied)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    'Microphone permission is required to record.',
                                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _openChat,
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Message your therapist'),
                              ),
                            ),
                          ],
                        ),
                        if (_recordedPath != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Voice clip saved locally. Upload and sharing will be enabled next.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _uploading ? null : _shareRecording,
                              icon: _uploading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.cloud_upload_outlined),
                              label: Text(_uploading ? 'Sharing…' : 'Share with Therapist'),
                            ),
                          ),
                        ],
                      ],
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
