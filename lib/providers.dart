import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'models/vocabulary_word.dart';
import 'repositories/vocabulary_repository.dart';
import 'services/translation_service.dart';

final _uuid = const Uuid();

/// Overridden in main() once Hive boxes are open.
final vocabularyRepositoryProvider = Provider<VocabularyRepository>((ref) {
  throw UnimplementedError('vocabularyRepositoryProvider must be overridden');
});

final translationServiceProvider = Provider<TranslationService>((ref) {
  final cache = Hive.box<String>(TranslationService.cacheBoxName);
  final svc = TranslationService(cache);
  ref.onDispose(svc.dispose);
  return svc;
});

final wordsProvider = StreamProvider<List<VocabularyWord>>((ref) {
  final repo = ref.watch(vocabularyRepositoryProvider);
  return repo.watch();
});

/// IDs whose translation is currently in flight. The UI uses this to render
/// a shimmer skeleton on the matching card.
final generatingIdsProvider =
    StateNotifierProvider<_GeneratingIds, Set<String>>((ref) {
  return _GeneratingIds();
});

class _GeneratingIds extends StateNotifier<Set<String>> {
  _GeneratingIds() : super(const {});
  void add(String id) => state = {...state, id};
  void remove(String id) => state = {...state}..remove(id);
}

class AddWordResult {
  final String id;
  final Object? error;
  const AddWordResult(this.id, {this.error});
  bool get ok => error == null;
}

/// Adds a word locally, kicks off translation in the background, and writes
/// the result back to the repository when it lands.
final addWordProvider =
    Provider<Future<AddWordResult> Function(String)>((ref) {
  return (String input) async {
    final text = input.trim();
    if (text.isEmpty) return const AddWordResult('', error: 'Empty input');

    final repo = ref.read(vocabularyRepositoryProvider);
    final translator = ref.read(translationServiceProvider);
    final generating = ref.read(generatingIdsProvider.notifier);

    final id = _uuid.v4();
    await repo.add(id: id, text: text);
    generating.add(id);

    try {
      final t = await translator.translate(text);
      await repo.updateTranslation(
        id,
        english: t.english,
        khmer: t.khmer,
        sourceLang: t.detectedLang,
        explanationKm: t.explanationKm,
        exampleEn: t.exampleEn,
        exampleKm: t.exampleKm,
        breakdownJson:
            t.breakdown.isEmpty ? null : jsonEncode(t.breakdown),
      );
      return AddWordResult(id);
    } catch (e) {
      // Translation failed (unsupported language, bad key, network, etc.) —
      // don't leave a half-written word polluting the list.
      await repo.delete(id);
      return AddWordResult(id, error: e);
    } finally {
      generating.remove(id);
    }
  };
});
