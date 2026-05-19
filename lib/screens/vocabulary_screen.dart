import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/vocabulary_word.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import 'widgets/add_word_sheet.dart';

enum WordFilter { all, learning, learned }

final _searchProvider = StateProvider<String>((ref) => '');
final _filterProvider = StateProvider<WordFilter>((ref) => WordFilter.all);

class VocabularyScreen extends ConsumerWidget {
  const VocabularyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wordsAsync = ref.watch(wordsProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: wordsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load: $e')),
          data: (words) => _Body(words: words),
        ),
      ),
      floatingActionButton: const _AddWordFab(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.words});
  final List<VocabularyWord> words;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(_searchProvider).trim().toLowerCase();
    final filter = ref.watch(_filterProvider);

    final filtered = words.where((w) {
      if (filter == WordFilter.learned && !w.learned) return false;
      if (filter == WordFilter.learning && w.learned) return false;
      if (query.isEmpty) return true;
      return w.english.toLowerCase().contains(query) ||
          w.khmer.toLowerCase().contains(query);
    }).toList(growable: false);

    final learned = words.where((w) => w.learned).length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _HeroPanel(total: words.length, learned: learned),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          sliver: SliverToBoxAdapter(child: _SearchBar()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          sliver: SliverToBoxAdapter(
            child: _FilterChips(
              all: words.length,
              learning: words.length - learned,
              learned: learned,
            ),
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(hasAny: words.isNotEmpty),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final w = filtered[i];
                return RepaintBoundary(
                  child: _WordCard(word: w)
                      .animate()
                      .fadeIn(duration: 220.ms, delay: (i * 18).ms)
                      .slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.total, required this.learned});
  final int total;
  final int learned;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : learned / total;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navy, AppColors.royal],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.royal.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khmer Vocabulary',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  total == 0
                      ? 'Start adding words'
                      : '$total ${total == 1 ? 'word' : 'words'}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '$learned learned · ${total - learned} learning',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _ProgressRing(progress: progress),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFB9CFFF)),
            ),
          ),
          Text(
            '${(progress * 100).round()}%',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      onChanged: (v) => ref.read(_searchProvider.notifier).state = v,
      decoration: InputDecoration(
        hintText: 'Search English or Khmer',
        prefixIcon: const Icon(Icons.search, color: AppColors.muted),
        suffixIcon: _ctrl.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, color: AppColors.muted),
                onPressed: () {
                  _ctrl.clear();
                  ref.read(_searchProvider.notifier).state = '';
                  setState(() {});
                },
              ),
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips(
      {required this.all, required this.learning, required this.learned});
  final int all;
  final int learning;
  final int learned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(_filterProvider);
    Widget chip(WordFilter f, String label, int count) {
      final selected = current == f;
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: ChoiceChip(
          showCheckmark: false,
          label: Text('$label  $count'),
          labelStyle: GoogleFonts.inter(
            color: selected ? Colors.white : AppColors.navy,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          backgroundColor: AppColors.ice,
          selectedColor: AppColors.royal,
          side: BorderSide(
            color: selected ? AppColors.royal : AppColors.border,
          ),
          selected: selected,
          onSelected: (_) => ref.read(_filterProvider.notifier).state = f,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    return Row(children: [
      chip(WordFilter.all, 'All', all),
      chip(WordFilter.learning, 'Learning', learning),
      chip(WordFilter.learned, 'Learned', learned),
    ]);
  }
}

class _WordCard extends ConsumerWidget {
  const _WordCard({required this.word});
  final VocabularyWord word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generating = ref.watch(generatingIdsProvider).contains(word.id);
    return Dismissible(
      key: ValueKey(word.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) =>
          ref.read(vocabularyRepositoryProvider).delete(word.id),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.royal.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: generating && !word.isTranslated
                      ? const _Shimmer()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              word.khmer.isEmpty ? '—' : word.khmer,
                              style: AppTheme.khmerDisplay(fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              word.english.isEmpty ? '—' : word.english,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
                _LearnedPill(word: word),
                const SizedBox(width: 4),
                _DeleteButton(word: word),
              ],
            ),
            if (!generating &&
                ((word.explanationKm?.isNotEmpty ?? false) ||
                    (word.exampleEn?.isNotEmpty ?? false))) ...[
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              if (word.explanationKm?.isNotEmpty ?? false)
                _CardDetailRow(
                  label: 'អត្ថន័យ',
                  labelStyle:
                      AppTheme.khmerDisplay(fontSize: 12, fontWeight: FontWeight.w700)
                          .copyWith(color: AppColors.royal, height: 1.25),
                  value: word.explanationKm!,
                  valueStyle: AppTheme.khmerDisplay(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                  ),
                ),
              if ((word.explanationKm?.isNotEmpty ?? false) &&
                  (word.exampleEn?.isNotEmpty ?? false))
                const SizedBox(height: 10),
              if (word.exampleEn?.isNotEmpty ?? false)
                _CardDetailRow(
                  label: 'Example',
                  labelStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.royal,
                    letterSpacing: 0.6,
                  ),
                  value: word.exampleEn!,
                  valueStyle: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: AppColors.navy,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                  trailing: (word.exampleKm?.isNotEmpty ?? false)
                      ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            word.exampleKm!,
                            style: AppTheme.khmerDisplay(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.muted,
                            ),
                          ),
                        )
                      : null,
                ),
              if ((word.exampleEn?.isNotEmpty ?? false) &&
                  word.breakdown.isNotEmpty) ...[
                const SizedBox(height: 10),
                _BreakdownSection(tokens: word.breakdown),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CardDetailRow extends StatelessWidget {
  const _CardDetailRow({
    required this.label,
    required this.value,
    required this.labelStyle,
    required this.valueStyle,
    this.trailing,
  });

  final String label;
  final String value;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: labelStyle),
        const SizedBox(height: 3),
        Text(value, style: valueStyle),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _BreakdownSection extends StatefulWidget {
  const _BreakdownSection({required this.tokens});
  final List<Map<String, String>> tokens;

  @override
  State<_BreakdownSection> createState() => _BreakdownSectionState();
}

class _BreakdownSectionState extends State<_BreakdownSection>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Word-by-word',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.royal,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.royal,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 240),
          sizeCurve: Curves.easeOutCubic,
          firstCurve: Curves.easeOutCubic,
          secondCurve: Curves.easeOutCubic,
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 2),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in widget.tokens)
                  _BreakdownPill(en: t['en'] ?? '', km: t['km'] ?? ''),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BreakdownPill extends StatelessWidget {
  const _BreakdownPill({required this.en, required this.km});
  final String en;
  final String km;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.ice,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            en,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            km,
            style: AppTheme.khmerDisplay(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer();
  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.ice,
            borderRadius: BorderRadius.circular(8),
          ),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fadeIn(duration: 600.ms)
            .then()
            .fade(begin: 1, end: 0.45, duration: 700.ms);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bar(180, 22),
        const SizedBox(height: 8),
        bar(120, 14),
      ],
    );
  }
}

class _DeleteButton extends ConsumerWidget {
  const _DeleteButton({required this.word});
  final VocabularyWord word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'Delete word',
      child: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        color: AppColors.muted,
        hoverColor: AppColors.danger.withValues(alpha: 0.08),
        splashRadius: 22,
        onPressed: () async {
          HapticFeedback.selectionClick();
          final repo = ref.read(vocabularyRepositoryProvider);
          final messenger = ScaffoldMessenger.of(context);
          final snapshot = VocabularyWord(
            id: word.id,
            english: word.english,
            khmer: word.khmer,
            sourceLang: word.sourceLang,
            learned: word.learned,
            createdAt: word.createdAt,
            learnedAt: word.learnedAt,
            explanationKm: word.explanationKm,
            exampleEn: word.exampleEn,
            exampleKm: word.exampleKm,
            breakdownJson: word.breakdownJson,
          );
          await repo.delete(word.id);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Word deleted'),
              action: SnackBarAction(
                label: 'Undo',
                textColor: Colors.white,
                onPressed: () => repo.restore(snapshot),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LearnedPill extends ConsumerWidget {
  const _LearnedPill({required this.word});
  final VocabularyWord word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learned = word.learned;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(vocabularyRepositoryProvider).toggleLearned(word.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: learned ? AppColors.royal : AppColors.ice,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: learned ? AppColors.royal : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween<double>(begin: 0.6, end: 1).animate(anim),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Icon(
                learned
                    ? Icons.check_circle_rounded
                    : Icons.school_outlined,
                key: ValueKey(learned),
                size: 18,
                color: learned ? Colors.white : AppColors.navy,
              ),
            ),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 260),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: learned ? Colors.white : AppColors.navy,
                letterSpacing: 0.2,
              ),
              child: Text(learned ? 'Learned' : 'Learning'),
            ),
          ],
        ),
      ).animate(target: learned ? 1 : 0).scaleXY(
            begin: 1,
            end: 1.04,
            duration: 160.ms,
            curve: Curves.easeOut,
          ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAny});
  final bool hasAny;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.ice,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.translate,
                  color: AppColors.royal, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              hasAny ? 'No matches' : 'Your vocabulary is empty',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasAny
                  ? 'Try a different search or filter.'
                  : 'Tap "Add word" to translate your first word.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddWordFab extends ConsumerWidget {
  const _AddWordFab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.royal, AppColors.navy],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.royal.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _openAddSheet(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Add word',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddWordSheet(),
    );
  }
}
