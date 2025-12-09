import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/models/user.dart' as app_user;
import 'package:therapii/services/voice_checkin_service.dart';
import 'package:just_audio/just_audio.dart';

class TherapistVoiceConversationPage extends StatefulWidget {
  final app_user.User patient;
  const TherapistVoiceConversationPage({super.key, required this.patient});

  @override
  State<TherapistVoiceConversationPage> createState() => _TherapistVoiceConversationPageState();
}

class _TherapistVoiceConversationPageState extends State<TherapistVoiceConversationPage> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _isRecording = false;
  bool _permissionDenied = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String? _recordedPath;
  bool _uploading = false;
  bool _isPlaying = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    if (_isRecording) {
      unawaited(_recorder.stop());
    }
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<String> _recordPath() async {
    final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    if (kIsWeb) return fileName; // web path is virtual; we only need a name
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
      // Load the recording for playback
      if (path != null) {
        try {
          if (kIsWeb) {
            // On web, record plugin returns Uint8List stored in memory
            // We need special handling - skip for now as web playback is tricky
          } else {
            await _player.setFilePath(path);
            _player.positionStream.listen((pos) {
              if (mounted) setState(() => _playbackPosition = pos);
            });
            _player.durationStream.listen((dur) {
              if (mounted && dur != null) setState(() => _playbackDuration = dur);
            });
            _player.playerStateStream.listen((state) {
              if (mounted) {
                setState(() => _isPlaying = state.playing);
                if (state.processingState == ProcessingState.completed) {
                  _player.seek(Duration.zero);
                  _player.pause();
                }
              }
            });
          }
        } catch (e) {
          debugPrint('Error loading audio for playback: $e');
        }
      }
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

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
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
      final svc = VoiceCheckinService();
      await svc.uploadAndShareRecording(
        localPath: _recordedPath!,
        patientId: widget.patient.id,
        therapistId: me.uid,
        durationSeconds: _elapsed.inSeconds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording saved to patient record.')),
      );
      setState(() {
        _recordedPath = null;
        _elapsed = Duration.zero;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload recording: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final patientName = widget.patient.fullName.isNotEmpty ? widget.patient.fullName : widget.patient.email;


    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Therapist Recording'),
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
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
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
                              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.10), shape: BoxShape.circle),
                              child: Icon(Icons.person_outline, color: scheme.primary),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text('Record a note for $patientName',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Capture a short voice update for the patient record.',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
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
                              Text(_isRecording ? 'Recording...' : (_recordedPath == null ? 'Ready to record' : 'Recorded clip ready'),
                                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary)),
                              const SizedBox(height: 16),
                              Text(_format(_elapsed),
                                  style: theme.textTheme.displaySmall?.copyWith(fontSize: 48, fontWeight: FontWeight.w800, color: scheme.onSurface)),
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
                                      child: Icon(_isRecording ? Icons.stop : Icons.mic,
                                          color: _isRecording ? scheme.error : scheme.primary, size: 42),
                                    ),
                                  ),
                                ),
                              ),
                              if (_permissionDenied)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text('Microphone permission is required to record.',
                                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
                                ),
                            ],
                          ),
                        ),
                        if (_recordedPath != null && !kIsWeb) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: _togglePlayback,
                                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                                  color: scheme.primary,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 2,
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                        ),
                                        child: Slider(
                                          value: _playbackDuration.inSeconds > 0
                                              ? _playbackPosition.inSeconds / _playbackDuration.inSeconds
                                              : 0.0,
                                          onChanged: (val) {
                                            final pos = Duration(seconds: (val * _playbackDuration.inSeconds).round());
                                            _player.seek(pos);
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(_format(_playbackPosition), style: theme.textTheme.bodySmall),
                                            Text(_format(_playbackDuration), style: theme.textTheme.bodySmall),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_recordedPath != null) ...[
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _uploading ? null : _shareRecording,
                              icon: _uploading
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.cloud_upload_outlined),
                              label: Text(_uploading ? 'Saving…' : 'Save to patient record'),
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
