import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

// TODO: paste your Anthropic API key here.
// Get one at https://console.anthropic.com/settings/keys
const String kAnthropicApiKey = 'YOUR_ANTHROPIC_API_KEY';

/// Backwards-compatible aliases for older imports.
const String kGeminiApiKey = kAnthropicApiKey;
const String kApiKey = kAnthropicApiKey;

/// Claude model used for translation. Sonnet 4.6 is the best speed/intelligence
/// balance for short translations and supports structured JSON output natively.
const String kClaudeModel = 'claude-sonnet-4-6';

const String _anthropicVersion = '2023-06-01';

class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);
  @override
  String toString() => message;
}

class Translation {
  final String english;
  final String khmer;
  final String detectedLang; // 'en' or 'km'
  final String explanationKm;
  final String exampleEn;
  final String exampleKm;
  final List<Map<String, String>> breakdown;

  const Translation({
    required this.english,
    required this.khmer,
    required this.detectedLang,
    required this.explanationKm,
    required this.exampleEn,
    required this.exampleKm,
    required this.breakdown,
  });
}

/// Wraps the Anthropic Messages API as a bilingual English/Khmer translator.
///
/// One call returns the translation, a Khmer explanation, an English example
/// sentence, its Khmer translation, and a word-by-word breakdown. Results are
/// cached in a Hive `Box<String>` (keyed `lang:text`, value is JSON) so
/// repeated lookups don't re-bill.
class TranslationService {
  TranslationService(this._cache, {http.Client? client})
      : _client = client ?? http.Client();

  static const String cacheBoxName = 'translationCache';

  final Box<String> _cache;
  final http.Client _client;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  Future<Translation> translate(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw TranslationException('Empty input');
    }
    if (kAnthropicApiKey.isEmpty ||
        kAnthropicApiKey == 'YOUR_ANTHROPIC_API_KEY') {
      throw TranslationException(
        'No API key configured. Open lib/services/translation_service.dart and set kAnthropicApiKey.',
      );
    }

    final hint = _detect(trimmed);
    final cacheProbeKey = '$hint:$trimmed';
    final cached = _cache.get(cacheProbeKey);
    if (cached != null) {
      final fromCache = _tryDecodeCache(cached, trimmed, hint);
      if (fromCache != null) return fromCache;
    }

    final result = await _askClaude(trimmed, hint: hint);
    final detected = result.detectedLang;

    final english = detected == 'en' ? trimmed : result.english;
    final khmer = detected == 'km' ? trimmed : result.khmer;

    final hydrated = Translation(
      english: english,
      khmer: khmer,
      detectedLang: detected,
      explanationKm: result.explanationKm,
      exampleEn: result.exampleEn,
      exampleKm: result.exampleKm,
      breakdown: result.breakdown,
    );

    await _cache.put(
      '$detected:$trimmed',
      jsonEncode({
        'english': english,
        'khmer': khmer,
        'explanationKm': hydrated.explanationKm,
        'exampleEn': hydrated.exampleEn,
        'exampleKm': hydrated.exampleKm,
        'breakdown': hydrated.breakdown,
      }),
    );

    return hydrated;
  }

  Translation? _tryDecodeCache(String raw, String input, String detected) {
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final rawBreakdown = m['breakdown'];
      final breakdown = <Map<String, String>>[];
      if (rawBreakdown is List) {
        for (final entry in rawBreakdown) {
          if (entry is Map) {
            breakdown.add({
              'en': (entry['en'] as String?) ?? '',
              'km': (entry['km'] as String?) ?? '',
            });
          }
        }
      }
      return Translation(
        english: (m['english'] as String?) ?? (detected == 'en' ? input : ''),
        khmer: (m['khmer'] as String?) ?? (detected == 'km' ? input : ''),
        detectedLang: detected,
        explanationKm: (m['explanationKm'] as String?) ?? '',
        exampleEn: (m['exampleEn'] as String?) ?? '',
        exampleKm: (m['exampleKm'] as String?) ?? '',
        breakdown: breakdown,
      );
    } catch (_) {
      return null;
    }
  }

  /// Local language hint — any Khmer codepoint -> 'km', else 'en'.
  /// Claude still makes the final determination via the `source_lang` field.
  String _detect(String text) {
    final hasKhmer = RegExp(r'[ក-៿]').hasMatch(text);
    return hasKhmer ? 'km' : 'en';
  }

  Future<Translation> _askClaude(
    String text, {
    required String hint,
  }) async {
    const systemPrompt = '''
You are a bilingual English-Khmer dictionary assistant.

This app only supports English and Khmer. The user gives you a word or short phrase. First identify the language of the input. Then produce a JSON object that matches the provided schema:

- "source_lang": exactly one of "en" (English), "km" (Khmer), or "other" if the input is neither English nor Khmer (for example Vietnamese, Thai, Chinese, Spanish, French, romanized Khmer, etc.).
- "english": the English form of the word. Empty string if source_lang is "other".
- "khmer": the Khmer form of the word in Khmer script. Empty string if source_lang is "other".
- "explanation_km": a short, plain-Khmer explanation (one or two sentences) of what the word means, written entirely in Khmer script. Empty string if source_lang is "other".
- "example_en": one natural English example sentence that uses the English form of the word. Empty string if source_lang is "other".
- "example_km": the Khmer translation of "example_en", written entirely in Khmer script. Must be a faithful translation of the same sentence. Empty string if source_lang is "other".
- "breakdown": an ordered array giving a word-by-word breakdown of "example_en". Each element is an object with "en" (one English word or short multi-word unit from the sentence, in order) and "km" (its Khmer equivalent in Khmer script). Cover every word in "example_en" in order, including small function words like "the", "a", "is". Use Khmer particles or short phrases where there is no exact one-word equivalent. Empty array if source_lang is "other".

Be strict: if the input is romanized/transliterated Khmer (Khmer in Latin letters) or any other non-English non-Khmer language, set source_lang to "other".''';

    final body = jsonEncode({
      'model': kClaudeModel,
      'max_tokens': 1024,
      'system': systemPrompt,
      'output_config': {
        'format': {
          'type': 'json_schema',
          'schema': {
            'type': 'object',
            'properties': {
              'source_lang': {
                'type': 'string',
                'enum': ['en', 'km', 'other'],
              },
              'english': {'type': 'string'},
              'khmer': {'type': 'string'},
              'explanation_km': {'type': 'string'},
              'example_en': {'type': 'string'},
              'example_km': {'type': 'string'},
              'breakdown': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'properties': {
                    'en': {'type': 'string'},
                    'km': {'type': 'string'},
                  },
                  'required': ['en', 'km'],
                  'additionalProperties': false,
                },
              },
            },
            'required': [
              'source_lang',
              'english',
              'khmer',
              'explanation_km',
              'example_en',
              'example_km',
              'breakdown',
            ],
            'additionalProperties': false,
          },
        },
      },
      'messages': [
        {
          'role': 'user',
          'content': 'Input (script hint: $hint): $text',
        }
      ],
    });

    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(_endpoint),
            headers: const {
              'content-type': 'application/json',
              'x-api-key': kAnthropicApiKey,
              'anthropic-version': _anthropicVersion,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      throw TranslationException('Network error: $e');
    }

    final decoded = _decode(res);

    final String rawJson;
    try {
      final content = decoded['content'] as List?;
      if (content == null || content.isEmpty) {
        throw TranslationException('Claude returned no content.');
      }
      // Find the first text block. With output_config.format = json_schema,
      // Claude returns a single text block whose body is valid JSON.
      String? text;
      for (final block in content) {
        if (block is Map && block['type'] == 'text') {
          text = block['text'] as String?;
          break;
        }
      }
      if (text == null || text.trim().isEmpty) {
        throw TranslationException('Claude returned an empty response.');
      }
      rawJson = text.trim();
    } on TranslationException {
      rethrow;
    } catch (_) {
      throw TranslationException('Unexpected response from Claude API.');
    }

    final Map<String, dynamic> obj;
    try {
      obj = jsonDecode(_stripFences(rawJson)) as Map<String, dynamic>;
    } catch (_) {
      throw TranslationException('Claude did not return valid JSON.');
    }

    final detectedLang = ((obj['source_lang'] as String?) ?? '').toLowerCase();
    if (detectedLang != 'en' && detectedLang != 'km') {
      throw TranslationException(
        'Only English and Khmer are supported. The input doesn\'t look like either.',
      );
    }

    final rawBreakdown = obj['breakdown'];
    final breakdown = <Map<String, String>>[];
    if (rawBreakdown is List) {
      for (final entry in rawBreakdown) {
        if (entry is Map) {
          final en = ((entry['en'] as String?) ?? '').trim();
          final km = ((entry['km'] as String?) ?? '').trim();
          if (en.isNotEmpty || km.isNotEmpty) {
            breakdown.add({'en': en, 'km': km});
          }
        }
      }
    }

    return Translation(
      english: _clean((obj['english'] as String?) ?? ''),
      khmer: _clean((obj['khmer'] as String?) ?? ''),
      detectedLang: detectedLang,
      explanationKm: ((obj['explanation_km'] as String?) ?? '').trim(),
      exampleEn: ((obj['example_en'] as String?) ?? '').trim(),
      exampleKm: ((obj['example_km'] as String?) ?? '').trim(),
      breakdown: breakdown,
    );
  }

  /// Defensive: strip ```json ... ``` fences if the model ignores
  /// the schema constraint and wraps the JSON in markdown.
  String _stripFences(String s) {
    var t = s.trim();
    if (t.startsWith('```')) {
      final firstNewline = t.indexOf('\n');
      if (firstNewline != -1) t = t.substring(firstNewline + 1);
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    }
    return t.trim();
  }

  String _clean(String raw) {
    var s = raw.trim();
    const pairs = [
      ['"', '"'],
      ["'", "'"],
      ['“', '”'],
      ['‘', '’'],
      ['«', '»'],
    ];
    for (final p in pairs) {
      if (s.length >= 2 && s.startsWith(p[0]) && s.endsWith(p[1])) {
        s = s.substring(1, s.length - 1).trim();
      }
    }
    if (s.endsWith('.')) s = s.substring(0, s.length - 1).trim();
    return s;
  }

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    if (res.statusCode == 400) {
      throw TranslationException(
        'Bad request to Claude (status 400). Check the model name and payload.',
      );
    }
    if (res.statusCode == 401) {
      throw TranslationException(
        'Invalid Anthropic API key (status 401).',
      );
    }
    if (res.statusCode == 403) {
      throw TranslationException(
        'API key lacks permission for this model (status 403).',
      );
    }
    if (res.statusCode == 404) {
      throw TranslationException(
        'Unknown model "$kClaudeModel" (status 404).',
      );
    }
    if (res.statusCode == 429) {
      throw TranslationException('Anthropic rate limit hit. Try again shortly.');
    }
    if (res.statusCode == 529) {
      throw TranslationException(
        'Anthropic API overloaded (status 529). Try again shortly.',
      );
    }
    if (res.statusCode >= 500) {
      throw TranslationException(
        'Claude server error (status ${res.statusCode}). Try again.',
      );
    }
    throw TranslationException(
      'Claude API error (status ${res.statusCode}).',
    );
  }

  void dispose() => _client.close();
}
