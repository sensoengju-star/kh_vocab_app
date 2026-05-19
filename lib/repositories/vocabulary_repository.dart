import 'package:hive/hive.dart';

import '../models/vocabulary_word.dart';

class VocabularyRepository {
  VocabularyRepository(this._box);

  static const String boxName = 'vocabulary';

  final Box<VocabularyWord> _box;

  List<VocabularyWord> all() {
    final list = _box.values.toList(growable: false);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Stream<List<VocabularyWord>> watch() async* {
    yield all();
    yield* _box.watch().map((_) => all());
  }

  Future<VocabularyWord> add({
    required String id,
    required String text,
  }) async {
    final word = VocabularyWord(
      id: id,
      english: '',
      khmer: '',
      sourceLang: '',
      learned: false,
      createdAt: DateTime.now(),
    );
    // Seed the user's input into the matching language so the card has
    // something to show during the shimmer.
    final hasKhmer = RegExp(r'[ក-៿]').hasMatch(text);
    if (hasKhmer) {
      word.khmer = text;
      word.sourceLang = 'km';
    } else {
      word.english = text;
      word.sourceLang = 'en';
    }
    await _box.put(id, word);
    return word;
  }

  Future<void> updateTranslation(
    String id, {
    required String english,
    required String khmer,
    required String sourceLang,
    String? explanationKm,
    String? exampleEn,
    String? exampleKm,
  }) async {
    final word = _box.get(id);
    if (word == null) return;
    word.english = english;
    word.khmer = khmer;
    word.sourceLang = sourceLang;
    word.explanationKm = explanationKm;
    word.exampleEn = exampleEn;
    word.exampleKm = exampleKm;
    await word.save();
  }

  Future<void> toggleLearned(String id) async {
    final word = _box.get(id);
    if (word == null) return;
    word.learned = !word.learned;
    word.learnedAt = word.learned ? DateTime.now() : null;
    await word.save();
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  Future<void> restore(VocabularyWord word) async {
    await _box.put(word.id, word);
  }
}
