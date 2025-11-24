import 'package:therapii/openai/openai_config.dart';

class OpenAIConfigurationException implements Exception {
  OpenAIConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'OpenAIConfigurationException: $message';
}

class OpenAIRequestException implements Exception {
  OpenAIRequestException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'OpenAIRequestException($statusCode): $message';
}

class OpenAITrainingResult {
  OpenAITrainingResult({
    required this.responseId,
    required this.model,
    required this.outputText,
    this.usage,
  });

  final String responseId;
  final String model;
  final String outputText;
  final Map<String, dynamic>? usage;
}

class OpenAITrainer {
  const OpenAITrainer();

  static const String _systemPrompt =
      'You are Therapii\'s AI personalization engine. Given real therapist data, craft a concise training brief that captures their tone, methods, and preferences for downstream chat fine-tuning.';

  // We now call OpenAI directly using AiCompanionClient instead of routing
  // through Cloud Functions. This avoids callable "internal" errors and
  // unifies behavior with the rest of the app's AI features.

  Future<OpenAITrainingResult> trainTherapistProfile({
    required String prompt,
    String model = 'gpt-4o',
    int maxOutputTokens = 1200,
  }) async {
    try {
      final client = const AiCompanionClient();
      final messages = _buildChatMessages(prompt)
          .map((m) => AiChatMessage(role: m['role'] as String, content: m['content'] as String))
          .toList(growable: false);

      final text = await client.sendChat(
        messages: messages,
        model: model,
        maxOutputTokens: maxOutputTokens,
      );

      if (text.trim().isEmpty) {
        throw OpenAIRequestException(500, 'OpenAI did not return any text.');
      }

      return OpenAITrainingResult(
        responseId: 'response-local',
        model: model,
        outputText: text.trim(),
        usage: null,
      );
    } on AiChatException catch (e) {
      // Surface configuration-type errors separately for clearer UX
      final msg = e.message.trim();
      if (msg.toLowerCase().contains('not configured')) {
        throw OpenAIConfigurationException(msg);
      }
      throw OpenAIRequestException(e.statusCode ?? 500, msg);
    } catch (error) {
      throw OpenAIRequestException(500, 'Unexpected error while training AI profile: $error');
    }
  }

  static List<Map<String, dynamic>> _buildChatMessages(String prompt) {
    return [
      {
        'role': 'system',
        'content': _systemPrompt,
      },
      {
        'role': 'user',
        'content': prompt,
      },
    ];
  }

  // No longer needed, but keep for compatibility in case callers catch by status code
  static int _mapStatusCode(String code, dynamic details) => 500;
}