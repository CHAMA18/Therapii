import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:therapii/models/user.dart' as app_user;
import 'package:therapii/openai/openai_config.dart';
import 'package:therapii/services/ai_conversation_service.dart';
import 'package:therapii/models/ai_conversation_summary.dart';
import 'package:therapii/services/user_service.dart';
import 'package:therapii/pages/patient_ai_history_page.dart';

class AiTherapistChatPage extends StatefulWidget {
  /// The therapist ID whose AI model the patient will chat with.
  final String therapistId;
  /// The AI model name set by the therapist.
  final String aiName;

  const AiTherapistChatPage({
    super.key,
    required this.therapistId,
    required this.aiName,
  });

  @override
  State<AiTherapistChatPage> createState() => _AiTherapistChatPageState();
}

class _AiTherapistChatPageState extends State<AiTherapistChatPage> {
  final UserService _userService = UserService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiCompanionClient _client = const AiCompanionClient();
  StreamSubscription<String>? _responseSubscription;
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  
  late String _aiName;
  List<AiChatMessage> _conversation = <AiChatMessage>[];

  bool _sending = false;
  bool _loadingContext = true;
  String? _contextError;
  String? _personalizationSummary;
  app_user.User? _patientProfile;
  Map<String, dynamic>? _patientContext;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _aiName = widget.aiName;
    _initSpeech();
    _loadPatientContext();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }
  
  String _buildSystemPrompt() {
    final buffer = StringBuffer();
    buffer.write('You are $_aiName, Therapii\'s AI companion. Respond with warmth, empathy, and actionable guidance. '
        'Keep replies under 6 sentences, reinforce healthy coping techniques, and align with the patient\'s therapist-led goals.');

    final profile = _patientProfile;
    final context = _patientContext;

    if (profile != null) {
      final displayName = [profile.firstName, profile.lastName]
          .where((part) => part.trim().isNotEmpty)
          .join(' ')
          .trim();
      buffer
        ..writeln()
        ..writeln('Patient profile:')
        ..writeln('- Name: ${displayName.isEmpty ? profile.email : displayName}')
        ..writeln('- Email: ${profile.email}');
    }

    if (context != null && context.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Patient configuration and preferences:');

      final goals = _stringValue(context['therapy_goals']);
      if (goals.isNotEmpty) {
        buffer.writeln('- Therapy goals: $goals');
      }

      final focusAreas = _stringList(context['focus_areas']);
      if (focusAreas.isNotEmpty) {
        buffer.writeln('- Focus areas: ${focusAreas.join(', ')}');
      }

      final support = _stringValue(context['support_needs']);
      if (support.isNotEmpty) {
        buffer.writeln('- Support strategies that help: $support');
      }

      final checkInFrequency = _stringValue(context['check_in_frequency']);
      if (checkInFrequency.isNotEmpty) {
        buffer.writeln('- Preferred check-in cadence: $checkInFrequency');
      }

      final sendReminders = context['send_reminders'];
      if (sendReminders is bool) {
        buffer.writeln(sendReminders
            ? '- Offer gentle reminder check-ins if the patient goes quiet.'
            : '- Do not proactively send reminders unless asked.');
      }

      final shareSummaries = context['share_summaries_with_therapist'];
      if (shareSummaries is bool) {
        buffer.writeln(shareSummaries
            ? '- Summaries may be shared with the human therapist to stay aligned.'
            : '- Keep conversation summaries private unless the patient explicitly requests sharing.');
      }

      final anythingElse = _stringValue(context['anything_else']);
      if (anythingElse.isNotEmpty) {
        buffer.writeln('- Additional notes from the patient: $anythingElse');
      }
    } else {
      buffer
        ..writeln()
        ..writeln('If preferences are unclear, ask gentle follow-up questions to personalize the guidance.');
    }

    buffer
      ..writeln()
      ..writeln('Anchor every response in these preferences, reflect back key themes, and coordinate with the human therapist when appropriate.');

    return buffer.toString();
  }

  @override
  void dispose() {
    _responseSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<_DisplayedAiMessage> get _messages => _conversation
      .map((entry) => _DisplayedAiMessage(role: entry.role, text: entry.content))
      .toList(growable: false);

  Future<void> _handleSend({String? textOverride}) async {
    if (_sending) return;
    final text = (textOverride ?? _messageController.text).trim();
    if (text.isEmpty) return;

    await _responseSubscription?.cancel();
    _responseSubscription = null;

    FocusScope.of(context).unfocus();
    _messageController.clear();

    final userMessage = AiChatMessage(role: 'user', content: text);
    final messages = <AiChatMessage>[
      AiChatMessage(role: 'system', content: _buildSystemPrompt()),
      ..._conversation,
      userMessage,
    ];

    late final int responseIndex;
    final buffer = StringBuffer();

    setState(() {
      _sending = true;
      _conversation
        ..add(userMessage)
        ..add(const AiChatMessage(role: 'assistant', content: ''));
      responseIndex = _conversation.length - 1;
    });

    _scrollAfterDelay();

    final stream = _client.sendChatStream(messages: messages);
    _responseSubscription = stream.listen(
      (chunk) {
        if (!mounted) {
          return;
        }
        if (chunk.trim().isEmpty) {
          return;
        }
        buffer.write(chunk);
        setState(() {
          _conversation[responseIndex] = AiChatMessage(role: 'assistant', content: buffer.toString());
        });
        _scrollAfterDelay();
      },
      onError: (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          if (_conversation.length > responseIndex) {
            _conversation.removeAt(responseIndex);
          }
          _sending = false;
        });
        final message = error is AiChatException
            ? error.message
            : 'We couldn\'t reach $_aiName right now. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        final subscription = _responseSubscription;
        _responseSubscription = null;
        subscription?.cancel();
      },
      onDone: () {
        if (!mounted) {
          return;
        }
        if (buffer.isEmpty) {
          setState(() {
            if (_conversation.length > responseIndex) {
              _conversation.removeAt(responseIndex);
            }
            _sending = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The AI companion returned an empty response.')),
          );
        } else {
          setState(() {
            _sending = false;
          });
        }
        final subscription = _responseSubscription;
        _responseSubscription = null;
        subscription?.cancel();
      },
      cancelOnError: false,
    );
  }

  void _scrollAfterDelay() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 120));
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PatientAiHistoryPage()),
    );
  }

  Future<void> _loadPatientContext() async {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      setState(() {
        _loadingContext = false;
        _contextError = 'You are not signed in. The AI companion will respond with general guidance.';
        _conversation = [
          AiChatMessage(
            role: 'assistant',
            content:
                'Hi, I am $_aiName, your Therapii AI companion. I\'m here whenever you need to check in, reflect, or plan your next steps. What\'s on your mind right now?',
          ),
        ];
      });
      return;
    }

    try {
      final profile = await _userService.getUser(firebaseUser.uid);
      if (!mounted) return;
      
      final context = profile?.patientOnboardingData;
      final summary = _buildPersonalizationSummary(context);
      setState(() {
        _patientProfile = profile?.copyWith(therapistId: widget.therapistId);
        _patientContext = context != null && context.isNotEmpty ? context : null;
        _personalizationSummary = summary;
        _loadingContext = false;
        _contextError = null;
        _conversation = [
          AiChatMessage(
            role: 'assistant',
            content:
                'Hi, I am $_aiName, your Therapii AI companion. I\'m here whenever you need to check in, reflect, or plan your next steps. What\'s on your mind right now?',
          ),
        ];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingContext = false;
        _contextError = 'We couldn\'t load your preferences. Responses may be more general until you refresh.';
        _conversation = [
          AiChatMessage(
            role: 'assistant',
            content:
                'Hi, I am $_aiName, your Therapii AI companion. I\'m here whenever you need to check in, reflect, or plan your next steps. What\'s on your mind right now?',
          ),
        ];
      });
    }
  }



  String? _buildPersonalizationSummary(Map<String, dynamic>? context) {
    if (context == null || context.isEmpty) {
      return null;
    }

    final highlights = <String>[];

    final focusAreas = _stringList(context['focus_areas']);
    if (focusAreas.isNotEmpty) {
      highlights.add('Focus: ${focusAreas.join(', ')}');
    }

    final checkInFrequency = _stringValue(context['check_in_frequency']);
    if (checkInFrequency.isNotEmpty) {
      highlights.add('Check-ins: $checkInFrequency');
    }

    final sendReminders = context['send_reminders'];
    if (sendReminders is bool) {
      highlights.add(sendReminders ? 'Reminders on' : 'Reminders off');
    }

    final shareSummaries = context['share_summaries_with_therapist'];
    if (shareSummaries is bool) {
      highlights.add(shareSummaries ? 'Therapist synced' : 'Therapist private');
    }

    final goals = _stringValue(context['therapy_goals']);
    if (goals.isNotEmpty) {
      highlights.insert(0, 'Goals: $goals');
    }

    if (highlights.isEmpty) {
      return null;
    }

    const maxItems = 3;
    return highlights.take(maxItems).join(' • ');
  }

  String _stringValue(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return const <String>[];
  }

  Widget? _buildContextNotice(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadingContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Personalizing $_aiName with your preferences…',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_personalizationSummary != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_pin_circle_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _personalizationSummary!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_contextError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.error.withOpacity(0.4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _contextError!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = _messages;
    final contextNotice = _buildContextNotice(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Chat with $_aiName'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
            onPressed: _openHistory,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _ending ? null : _onEndConversation,
              icon: _ending
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.stop_circle_outlined),
              label: const Text('End Conversation'),
            ),
          ),
        ],
      ),
      // Drawer removed as Text-to-Speech is no longer supported here
      body: SafeArea(
        child: Column(
          children: [
            if (contextNotice != null) contextNotice,
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isUser = message.role == 'user';

                  return Align(
                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: isUser
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isUser ? 18 : 6),
                          bottomRight: Radius.circular(isUser ? 6 : 18),
                        ),
                        boxShadow: [
                          if (!isUser)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 8),
                            ),
                        ],
                      ),
                      child: Text(
                        message.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isUser ? Colors.white : theme.colorScheme.onSurface,
                          height: 1.45,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_speechAvailable)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        height: 46,
                        width: 46,
                        child: FilledButton.tonal(
                          onPressed: (_sending || _isListening) ? null : _toggleListening,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                            backgroundColor: _isListening 
                                ? theme.colorScheme.error.withOpacity(0.2)
                                : theme.colorScheme.secondaryContainer,
                          ),
                          child: _isListening
                              ? const Icon(Icons.stop, size: 20, color: Colors.red)
                              : const Icon(Icons.mic, size: 20),
                        ),
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.newline,
                      maxLines: 5,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Share how you\'re feeling or ask a question…',
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    width: 46,
                    child: FilledButton(
                      onPressed: _sending ? null : _handleSend,
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                            )
                          : const Icon(Icons.send, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplayedAiMessage {
  const _DisplayedAiMessage({required this.role, required this.text});

  final String role;
  final String text;
}

extension _SpeechActions on _AiTherapistChatPageState {
  Future<void> _initSpeech() async {
    // Disable Speech-to-Text on web to avoid runtime errors from the Web Speech API
    // in hot-restart environments (Bad state: Cannot add new events after calling close)
    if (kIsWeb) {
      if (mounted) {
        setState(() => _speechAvailable = false);
      }
      return;
    }

    try {
      final available = await _speechToText.initialize(
        onError: (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Speech recognition error: ${error.errorMsg}')),
            );
          }
        },
        onStatus: (status) {
          if (mounted && status == 'done') {
            setState(() => _isListening = false);
          }
        },
      );
      if (mounted) {
        setState(() => _speechAvailable = available);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _speechAvailable = false);
      }
    }
  }

  Future<void> _toggleListening() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice input is not available on web in this build.')),
        );
      }
      return;
    }

    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      final available = await _speechToText.initialize();
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition not available on this device.')),
          );
        }
        return;
      }

      setState(() => _isListening = true);
      
      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _messageController.text = result.recognizedWords;
            });
            if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
              _handleSend(textOverride: result.recognizedWords);
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
      );
    }
  }
}

extension _SummaryActions on _AiTherapistChatPageState {
  Future<void> _onEndConversation() async {
    if (_ending) return;
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be signed in to save the conversation.')),
      );
      return;
    }

    final therapistId = widget.therapistId;
    if (therapistId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No therapist is linked to your account yet.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End conversation?'),
        content: const Text(
            'We will summarize this chat and share it with your therapist so they can review it.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('End & Share')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _ending = true);

    final transcript = _conversation
        .map((m) => '${m.role == 'user' ? 'Patient' : m.role == 'assistant' ? 'AI' : m.role}: ${m.content}')
        .join('\n');

    const system =
        'You are Therapii\'s clinical summarizer. Read the transcript and produce a concise, therapist-facing summary. '
        'Include: key themes, mood, notable triggers, coping strategies discussed, and suggested next steps. '
        'Use short paragraphs and bullet points where helpful. Keep it under 250 words.';

    try {
      // ignore: avoid_print
      print('[AI-SUMMARY] onEndConversation begin user=${firebaseUser.uid} therapist=$therapistId messages=${_conversation.length}');
      final messages = <AiChatMessage>[
        const AiChatMessage(role: 'system', content: system),
        AiChatMessage(role: 'user', content: 'Transcript of the patient-AI conversation:\n$transcript'),
      ];
      // Prefer Chat Completions for summarization to avoid Responses-proxy schema mismatches
      final summary = await _client.sendChat(messages: messages, maxOutputTokens: 2000, preferChatCompletions: true);
      // ignore: avoid_print
      print('[AI-SUMMARY] summary generated length=${summary.length}');

      final parts = _conversation
          .map((m) => AiMessagePart(role: m.role, text: m.content))
          .toList(growable: false);
      final service = AiConversationService();
      await service.saveSummary(
        patientId: firebaseUser.uid,
        therapistId: therapistId,
        summary: summary,
        transcript: parts,
      );

      if (!mounted) return;
      setState(() => _ending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation summarized and shared with your therapist.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _ending = false);
      // ignore: avoid_print
      print('[AI-SUMMARY] onEndConversation error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save summary: $e')),
      );
    }
  }
}
