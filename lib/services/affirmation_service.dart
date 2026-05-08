import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AffirmationService {
  AffirmationService._();
  static final AffirmationService instance = AffirmationService._();

  static const String _baseUrl =
      'https://api.openai.com/v1/chat/completions';
  static const String _prefKey = 'daily_affirmation';
  static const String _prefDateKey = 'daily_affirmation_date';

  // Fallback affirmations when API is unavailable
  static const List<String> _fallbacks = [
    'You are capable of amazing things. One small step today matters.',
    'Your feelings are valid. You deserve kindness — especially from yourself.',
    'Every breath is a fresh start. You are doing better than you think.',
    'It is okay to not be okay. Reaching out is a sign of strength.',
    'Progress is progress, no matter how small. Be proud of yourself today.',
    'You have survived every difficult day so far. You will survive this one too.',
    'Your mental health matters. Taking care of yourself is never selfish.',
    'You are enough, exactly as you are, right now.',
    'Difficult roads often lead to beautiful destinations. Keep going.',
    'You are worthy of love, peace, and happiness.',
  ];

  String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';

  // ── Get today's affirmation ───────────────
  // Returns a cached affirmation if already fetched today,
  // otherwise fetches from OpenAI and caches the result.
  Future<String> getTodayAffirmation() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final cachedDate = prefs.getString(_prefDateKey);
    final cached = prefs.getString(_prefKey);

    if (cachedDate == today && cached != null && cached.isNotEmpty) {
      return cached;
    }

    // Try to fetch from OpenAI
    if (_apiKey.isNotEmpty) {
      try {
        final affirmation = await _fetchFromOpenAI();
        await prefs.setString(_prefKey, affirmation);
        await prefs.setString(_prefDateKey, today);
        return affirmation;
      } catch (_) {
        // Fall through to fallback
      }
    }

    // Use deterministic fallback based on day of year
    final dayOfYear = DateTime.now().difference(
          DateTime(DateTime.now().year, 1, 1),
        ).inDays;
    final fallback = _fallbacks[dayOfYear % _fallbacks.length];

    await prefs.setString(_prefKey, fallback);
    await prefs.setString(_prefDateKey, today);
    return fallback;
  }

  Future<String> _fetchFromOpenAI() async {
    final response = await http
        .post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': [
              {
                'role': 'system',
                'content':
                    'You write short, warm, and uplifting daily affirmations '
                    'for a mental health app. Each affirmation should be '
                    '1–2 sentences, personal, and avoid clichés. '
                    'Do not use asterisks, quotes, or any formatting. '
                    'Just the affirmation text.',
              },
              {
                'role': 'user',
                'content':
                    'Give me one unique daily affirmation for today. '
                    'Make it feel genuine and human.',
              },
            ],
            'max_tokens': 80,
            'temperature': 0.9,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = (data['choices'] as List<dynamic>)[0]['message']
          ['content'] as String? ?? '';
      return content.trim();
    }
    throw Exception('OpenAI error: ${response.statusCode}');
  }

  // ── Force refresh ─────────────────────────
  Future<String> refreshAffirmation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    await prefs.remove(_prefDateKey);
    return getTodayAffirmation();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}
