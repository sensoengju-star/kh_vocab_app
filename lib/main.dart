import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/vocabulary_word.dart';
import 'providers.dart';
import 'repositories/vocabulary_repository.dart';
import 'screens/vocabulary_screen.dart';
import 'services/translation_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(VocabularyWordAdapter());

  final wordsBox =
      await Hive.openBox<VocabularyWord>(VocabularyRepository.boxName);
  await Hive.openBox<String>(TranslationService.cacheBoxName);

  final repo = VocabularyRepository(wordsBox);

  runApp(
    ProviderScope(
      overrides: [
        vocabularyRepositoryProvider.overrideWithValue(repo),
      ],
      child: const KhVocabApp(),
    ),
  );
}

class KhVocabApp extends StatelessWidget {
  const KhVocabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Khmer Vocabulary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const VocabularyScreen(),
    );
  }
}
