import 'package:hive/hive.dart';

part 'vocabulary_word.g.dart';

@HiveType(typeId: 1)
class VocabularyWord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String english;

  @HiveField(2)
  String khmer;

  /// 'en' or 'km' — the language the user originally typed.
  @HiveField(3)
  String sourceLang;

  @HiveField(4)
  bool learned;

  @HiveField(5)
  DateTime createdAt;

  @HiveField(6)
  DateTime? learnedAt;

  /// Short Khmer-language explanation of the word's meaning.
  @HiveField(7)
  String? explanationKm;

  /// Example sentence in English using the word.
  @HiveField(8)
  String? exampleEn;

  /// Khmer translation of the English example sentence.
  @HiveField(9)
  String? exampleKm;

  VocabularyWord({
    required this.id,
    required this.english,
    required this.khmer,
    required this.sourceLang,
    required this.learned,
    required this.createdAt,
    this.learnedAt,
    this.explanationKm,
    this.exampleEn,
    this.exampleKm,
  });

  bool get isTranslated => english.isNotEmpty && khmer.isNotEmpty;
}
