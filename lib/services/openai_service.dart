import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/mood_entry.dart';

class OpenAIService {
  OpenAIService._();
  static final OpenAIService instance = OpenAIService._();

  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-4o-mini';
  static const int _maxTokens = 500;

  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  // ── Build system prompt ───────────────────
  // Injects today's mood entry when available so the chatbot
  // can respond with relevant, personalised support.
  String _buildSystemPrompt({MoodEntry? todayMood}) {
    final buffer = StringBuffer();

    buffer.write(
      'You are MindMate, a warm and compassionate mental health companion. '
      'Your role is to provide emotional support, active listening, '
      'and gentle guidance. You are not a therapist or medical professional — '
      'always remind users to seek professional help for serious concerns. '
      'Keep responses concise (2–4 sentences unless the user needs more). '
      'Use a caring, non-judgmental tone. '
      'If the user expresses thoughts of self-harm or suicide, always '
      'acknowledge their pain, encourage them to call a helpline immediately, '
      'and provide the SADAG number: 0800 21 22 23.',
    );

    if (todayMood != null) {
      buffer.write(
        "\n\nContext: The user logged their mood today as "
        "'${todayMood.moodLabel}' (${todayMood.moodScore}/10). "
        "${todayMood.note.isNotEmpty ? "They noted: '${todayMood.note}'." : ''} "
        "Use this context to make your responses more relevant, "
        "but do not repeat this information back verbatim.",
      );
    }

    return buffer.toString();
  }

  // ── Send message ──────────────────────────
  Future<String> sendMessage({
    required String userMessage,
    required String userId,
    required List<ChatMessage> history,
    MoodEntry? todayMood,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
          'OpenAI API key not set. Add OPENAI_API_KEY to your .env file.');
    }

    // Build messages array: system + history + new user message
    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': _buildSystemPrompt(todayMood: todayMood),
      },
      // Include recent history (already filtered to non-error messages)
      ...history
          .where((m) => m.role != 'system')
          .map((m) => m.toApiMessage()),
      {
        'role': 'user',
        'content': userMessage,
      },
    ];

    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': _model,
            'messages': messages,
            'max_tokens': _maxTokens,
            'temperature': 0.75,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>;
      if (choices.isEmpty) throw Exception('No response from OpenAI.');
      final content =
          choices[0]['message']['content'] as String? ?? '';
      return content.trim();
    } else if (response.statusCode == 401) {
      throw Exception('Invalid OpenAI API key. Check your .env file.');
    } else if (response.statusCode == 429) {
      throw Exception(
          'OpenAI rate limit reached. Please wait a moment and try again.');
    } else {
      final body = jsonDecode(response.body);
      throw Exception(
          body['error']?['message'] ?? 'OpenAI error: ${response.statusCode}');
    }
  }

  // ── Mood analysis ─────────────────────────
  // Analyses a chat conversation and returns a mood score 1-10.
  // Used optionally to track mood via chat.
  Future<int?> inferMoodFromChat(List<ChatMessage> messages) async {
    if (_apiKey.isEmpty || messages.isEmpty) return null;

    final userMessages = messages
        .where((m) => m.isUser)
        .map((m) => m.content)
        .join(' ');

    if (userMessages.trim().isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'Analyse the emotional tone of the following messages and return '
                      'ONLY a single integer from 1 to 10 representing the overall mood '
                      '(1 = very distressed, 10 = very positive). No explanation, just the number.',
                },
                {
                  'role': 'user',
                  'content': userMessages,
                },
              ],
              'max_tokens': 5,
              'temperature': 0.1,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (data['choices'] as List<dynamic>)[0]['message']['content']
            as String? ?? '';
        final score = int.tryParse(text.trim());
        if (score != null && score >= 1 && score <= 10) return score;
      }
    } catch (_) {
      // Mood inference is non-critical — fail silently
    }
    return null;
  }
}
