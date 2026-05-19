import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

// TODO: paste your Gemini API key here.
// Get one (free tier available) at https://aistudio.google.com/app/apikey
const String kGeminiApiKey = 'AIzaSyDT76mzlGnLEgAlbUA1Bxg0F70aih0Tiq8';

/// Backwards-compatible alias so older imports referencing kApiKey still work.
const String kApiKey = kGeminiApiKey;

const String kGeminiModel = 'gemini-2.5-flash';

class TranslationException implements Exception {
  final String message;
  TranslationException(this.message);
  @override
  String toString() => message;
}

class Translation {
  final String english;
  final String khmer;
  final String detectedLang;

  /// Short Khmer-language explanation of the word's meaning.
  final String explanationKm;

  /// English example sentence using the word.
  final String exampleEn;

  /// Khmer translation of the English example sentence.
  final String exampleKm;

  /// Word-by-word breakdown of the example sentence. Each entry maps a token
  /// of the English sentence to its Khmer equivalent (`en` / `km`).
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

/// Wraps the Gemini generateContent endpoint.
///
/// One call returns: the translation, a short Khmer explanation, and an
/// English example sentence. Results are cached in a Hive `Box<String>`
/// (keyed `lang:text`, value is JSON) so repeated lookups don't re-bill.
class TranslationService {
  TranslationService(this._cache, {http.Client? client})
      : _client = client ?? http.Client();

  static const String cacheBoxName = 'translationCache';

  final Box<String> _cache;
  final http.Client _client;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  Future<Translation> translate(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw TranslationException('Empty input');
    }
    if (kGeminiApiKey.isEmpty || kGeminiApiKey == 'YOUR_GEMINI_API_KEY') {
      throw TranslationException(
        'No API key configured. Open lib/services/translation_service.dart and set kGeminiApiKey.',
      );
    }

    final hint = _detect(trimmed);
    final cacheProbeKey = '$hint:$trimmed';
    final cached = _cache.get(cacheProbeKey);
    if (cached != null) {
      final fromCache = _tryDecodeCache(cached, trimmed, hint);
      if (fromCache != null) return fromCache;
    }

    final result = await _askGemini(trimmed, hint: hint);
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
      // Legacy cache entries stored just the translated string — re-fetch.
      return null;
    }
  }

  String _detect(String text) {
    final hasKhmer = RegExp(r'[ក-៿]').hasMatch(text);
    return hasKhmer ? 'km' : 'en';
  }

  Future<Translation> _askGemini(
    String text, {
    required String hint,
  }) async {
    final prompt = '''
You are a bilingual English-Khmer dictionary assistant.

This app only supports English and Khmer. The user gave you a word or short phrase.

First, identify the language of the input. Then produce a strict JSON object with these keys:
- "source_lang": exactly one of "en" (English), "km" (Khmer), or "other" if it is neither English nor Khmer (for example Vietnamese, Thai, Chinese, Spanish, French, romanized Khmer, etc.).
- "english": the English form of the word. Empty string if source_lang is "other".
- "khmer": the Khmer form of the word in Khmer script. Empty string if source_lang is "other".
- "explanation_km": a short, plain-Khmer explanation (one or two sentences) of what the word means, written entirely in Khmer script. Empty string if source_lang is "other".
- "example_en": one natural English example sentence that uses the English form of the word. Empty string if source_lang is "other".
- "example_km": the Khmer translation of "example_en", written entirely in Khmer script. It must be a faithful translation of the same sentence. Empty string if source_lang is "other".
- "breakdown": an ordered array giving a word-by-word breakdown of "example_en". Each element is an object with two keys: "en" (one English word or short multi-word unit from the sentence, in the order it appears) and "km" (its Khmer equivalent in Khmer script). Cover every word in "example_en", including small function words like "the", "a", "is", in order. Use Khmer particles or short phrases where there is no exact one-word equivalent. Empty array if source_lang is "other".

Be strict: if the input is romanized/transliterated Khmer (Khmer written in Latin letters) or any other non-English non-Khmer language, set source_lang to "other".

Return JSON only, no markdown, no backticks, no commentary.

Input (script hint: $hint): $text
''';

    final uri = Uri.parse(
      '$_base/models/$kGeminiModel:generateContent?key=$kGeminiApiKey',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 512,
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'source_lang': {
              'type': 'STRING',
              'enum': ['en', 'km', 'other'],
            },
            'english': {'type': 'STRING'},
            'khmer': {'type': 'STRING'},
            'explanation_km': {'type': 'STRING'},
            'example_en': {'type': 'STRING'},
            'example_km': {'type': 'STRING'},
            'breakdown': {
              'type': 'ARRAY',
              'items': {
                'type': 'OBJECT',
                'properties': {
                  'en': {'type': 'STRING'},
                  'km': {'type': 'STRING'},
                },
                'required': ['en', 'km'],
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
        },
      },
    });

    final http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      throw TranslationException('Network error: $e');
    }

    final decoded = _decode(res);

    final String raw;
    try {
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        final blockReason =
            decoded['promptFeedback']?['blockReason'] as String?;
        throw TranslationException(
          blockReason != null
              ? 'Gemini blocked the request ($blockReason).'
              : 'Gemini returned no candidates.',
        );
      }
      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw TranslationException('Gemini returned an empty response.');
      }
      raw = ((parts[0]['text'] as String?) ?? '').trim();
      if (raw.isEmpty) {
        throw TranslationException('Gemini returned an empty translation.');
      }
    } on TranslationException {
      rethrow;
    } catch (_) {
      throw TranslationException('Unexpected response from Gemini API.');
    }

    final Map<String, dynamic> obj;
    try {
      obj = jsonDecode(_stripFences(raw)) as Map<String, dynamic>;
    } catch (_) {
      throw TranslationException('Gemini did not return valid JSON.');
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

  /// Strip ```json ... ``` fences in case the model ignores responseMimeType.
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
        'Bad request to Gemini (status 400). Check the model name and payload.',
      );
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw TranslationException(
        'Invalid or unauthorized Gemini API key (status ${res.statusCode}).',
      );
    }
    if (res.statusCode == 429) {
      throw TranslationException('Gemini quota or rate limit exhausted.');
    }
    if (res.statusCode >= 500) {
      throw TranslationException(
        'Gemini server error (status ${res.statusCode}). Try again.',
      );
    }
    throw TranslationException(
      'Gemini API error (status ${res.statusCode}).',
    );
  }

  void dispose() => _client.close();
}
