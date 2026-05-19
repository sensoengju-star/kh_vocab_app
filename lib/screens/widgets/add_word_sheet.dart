import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers.dart';
import '../../services/stt_service.dart';
import '../../services/win_voice_typing.dart';
import '../../theme/app_theme.dart';

class AddWordSheet extends ConsumerStatefulWidget {
  const AddWordSheet({super.key});

  @override
  ConsumerState<AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends ConsumerState<AddWordSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _localeId = 'en_US';
  bool _submitting = false;

  /// Windows Voice Typing gives no callback, so we mirror its on/off state
  /// locally to drive the mic UI.
  bool _winListening = false;

  /// The last STT-recognized string we wrote into the controller. We only
  /// re-sync from STT when this changes — otherwise typing/deleting in the
  /// field would get clobbered every rebuild.
  String _lastAppliedStt = '';

  bool get _isWindows => !kIsWebFake && Platform.isWindows;

  // Always false in this app (no web target), but guards Platform access.
  static const bool kIsWebFake = false;

  @override
  void initState() {
    super.initState();
    if (!_isWindows) {
      // Warm up the recognizer so the first tap is snappy.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sttProvider.notifier).initialize();
      });
    }
  }

  @override
  void dispose() {
    if (!_isWindows) {
      ref.read(sttProvider.notifier).cancel();
    }
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);

    final add = ref.read(addWordProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    final result = await add(text);
    if (!result.ok) {
      messenger.showSnackBar(SnackBar(content: Text(result.error.toString())));
    }
  }

  Future<void> _toggleMic() async {
    HapticFeedback.selectionClick();

    if (_isWindows) {
      // Focus the field first so Voice Typing dictates into it.
      _focus.requestFocus();
      final ok = WinVoiceTyping.toggle();
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Could not launch Windows Voice Typing. Press Win+H manually.'),
          ),
        );
        return;
      }
      setState(() => _winListening = !_winListening);
      return;
    }

    final stt = ref.read(sttProvider);
    final notifier = ref.read(sttProvider.notifier);
    if (stt.listening) {
      await notifier.stopListening();
    } else {
      _focus.unfocus();
      _lastAppliedStt = '';
      await notifier.startListening(localeId: _localeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stream non-Windows STT results into the controller and surface errors.
    if (!_isWindows) {
      ref.listen<SttState>(sttProvider, (prev, next) {
        // Only push STT text into the field while actively listening, and
        // only when the recognizer's output has actually changed. This keeps
        // the user free to edit / delete the text manually afterward.
        final wasListening = prev?.listening ?? false;
        if (next.listening &&
            next.recognized.isNotEmpty &&
            next.recognized != _lastAppliedStt) {
          _lastAppliedStt = next.recognized;
          _ctrl.value = TextEditingValue(
            text: next.recognized,
            selection:
                TextSelection.collapsed(offset: next.recognized.length),
          );
        }
        if (wasListening && !next.listening) {
          _lastAppliedStt = '';
        }
        if (next.error != null && next.error != prev?.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.error!)),
          );
          ref.read(sttProvider.notifier).clearError();
        }
      });
    }

    final listening =
        _isWindows ? _winListening : ref.watch(sttProvider).listening;

    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Add a word',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Type or speak in English or Khmer — translation is automatic.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            _LanguageToggle(
              value: _localeId,
              onChanged: (v) => setState(() => _localeId = v),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: !_isWindows,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              style: GoogleFonts.notoSansKhmer(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
                height: 1.4,
              ),
              decoration: InputDecoration(
                hintText:
                    listening ? 'Listening…' : 'Type or speak a word',
                hintStyle: GoogleFonts.inter(
                  color: listening ? AppColors.royal : AppColors.muted,
                  fontWeight:
                      listening ? FontWeight.w600 : FontWeight.w400,
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: RepaintBoundary(
                    child: _MicButton(
                      listening: listening,
                      onTap: _toggleMic,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.royal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Add & translate',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, String id, {TextStyle? style}) {
      final selected = value == id;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.royal : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 240),
              style: (style ?? GoogleFonts.inter()).copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.navy,
              ),
              child: Text(label),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.ice,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          seg('EN', 'en_US'),
          seg('ខ្មែរ', 'km_KH',
              style: GoogleFonts.notoSansKhmer(height: 1.2)),
        ],
      ),
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton({required this.listening, required this.onTap});
  final bool listening;
  final VoidCallback onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final listening = widget.listening;
    final bg = listening ? AppColors.royal : AppColors.ice;
    final fg = listening ? Colors.white : AppColors.royal;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (listening) ...[
                _PulseRing(delayFraction: 0.0),
                _PulseRing(delayFraction: 0.5),
              ],
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: listening ? AppColors.royal : AppColors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, anim) {
                    return FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.6, end: 1).animate(anim),
                        child: RotationTransition(
                          turns:
                              Tween<double>(begin: -0.15, end: 0).animate(anim),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Icon(
                    listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    key: ValueKey(listening),
                    size: 20,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing({required this.delayFraction});
  final double delayFraction;

  @override
  Widget build(BuildContext context) {
    const cycle = Duration(milliseconds: 1500);
    final delay = Duration(milliseconds: (1500 * delayFraction).round());
    return IgnorePointer(
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ice, width: 2),
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .custom(
            duration: cycle,
            delay: delay,
            builder: (context, value, child) {
              final size = 22.0 + (52.0 - 22.0) * value;
              final opacity = (0.55 * (1 - value)).clamp(0.0, 1.0);
              return Opacity(
                opacity: opacity,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.ice, width: 2),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }
}
