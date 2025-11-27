import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

class AiChatMessage {
  const AiChatMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

class AiChatException implements Exception {
  AiChatException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode != null ? 'AiChatException($statusCode): $message' : 'AiChatException: $message';
}

class AiCompanionClient {
  const AiCompanionClient();

  Future<String> sendChat({
    required List<AiChatMessage> messages,
    String model = 'gpt-4o',
    int maxOutputTokens = 2000,
    bool preferChatCompletions = false,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in sendChatStream(
      messages: messages,
      model: model,
      maxOutputTokens: maxOutputTokens,
      preferChatCompletions: preferChatCompletions,
    )) {
      buffer.write(chunk);
    }

    final response = buffer.toString().trim();
    if (response.isEmpty) {
      throw AiChatException('The AI companion returned an empty response.');
    }
    return response;
  }

  Stream<String> sendChatStream({
    required List<AiChatMessage> messages,
    String model = 'gpt-4o',
    int maxOutputTokens = 2000,
    bool preferChatCompletions = false,
  }) async* {
    if (messages.isEmpty) {
      throw AiChatException('At least one message is required to contact the AI companion.');
    }

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('generateAiChatCompletion');
      
      // ignore: avoid_print
      print('[AI] Calling Cloud Function: generateAiChatCompletion');
      
      final result = await callable.call({
        'messages': messages.map((m) => m.toJson()).toList(),
        'model': model,
        'maxOutputTokens': maxOutputTokens,
      });

      final data = result.data;
      if (data is Map) {
        final text = data['text'];
        if (text is String && text.trim().isNotEmpty) {
          // ignore: avoid_print
          print('[AI] Cloud Function returned text length: ${text.length}');
          yield text.trim();
          return;
        }
      }

      throw AiChatException('The AI companion returned an empty response.');
    } on FirebaseFunctionsException catch (e) {
      // ignore: avoid_print
      print('[AI] Cloud Function error: code=${e.code} message=${e.message}');
      
      final message = e.message ?? 'Failed to contact the AI companion.';
      
      // Check if this is a configuration error
      if (message.contains('not configured') || message.contains('API key')) {
        throw AiChatException('AI companion not configured. Admin users can configure it in Settings > Admin Settings.');
      }
      
      throw AiChatException(message);
    } on TimeoutException {
      throw AiChatException('The AI companion is taking too long to respond. Please try again.');
    } catch (error) {
      // ignore: avoid_print
      print('[AI] Unexpected error: $error');
      throw AiChatException('Unexpected error while contacting the AI companion: $error');
    }
  }
}

List<AiChatMessage> buildCompanionMessages({
  required String userMessage,
  required List<AiChatMessage> history,
  String? systemPrompt,
}) {
  final messages = <AiChatMessage>[];
  if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
    messages.add(AiChatMessage(role: 'system', content: systemPrompt.trim()));
  }
  messages.addAll(history);
  messages.add(AiChatMessage(role: 'user', content: userMessage));
  return messages;
}