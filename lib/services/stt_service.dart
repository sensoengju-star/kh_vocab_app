import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SttState {
  final bool initialized;
  final bool available;
  final bool listening;
  final String recognized;
  final String? error;

  const SttState({
    this.initialized = false,
    this.available = false,
    this.listening = false,
    this.recognized = '',
    this.error,
  });

  SttState copyWith({
    bool? initialized,
    bool? available,
    bool? listening,
    String? recognized,
    String? error,
    bool clearError = false,
  }) {
    return SttState(
      initialized: initialized ?? this.initialized,
      available: available ?? this.available,
      listening: listening ?? this.listening,
      recognized: recognized ?? this.recognized,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SttNotifier extends StateNotifier<SttState> {
  SttNotifier() : super(const SttState());

  final SpeechToText _speech = SpeechToText();

  Future<void> initialize() async {
    if (state.initialized) return;
    try {
      final available = await _speech.initialize(
        onError: _onError,
        onStatus: _onStatus,
      );
      state = state.copyWith(
        initialized: true,
        available: available,
        clearError: true,
      );
      if (!available) {
        state = state.copyWith(
          error: 'Speech recognition is not available on this device.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        initialized: true,
        available: false,
        error: 'Failed to initialize speech: $e',
      );
    }
  }

  Future<void> startListening({String localeId = 'en_US'}) async {
    if (!state.initialized) await initialize();
    if (!state.available || state.listening) return;
    state = state.copyWith(recognized: '', clearError: true);
    try {
      await _speech.listen(
        localeId: localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
        onResult: _onResult,
      );
      state = state.copyWith(listening: true);
    } catch (e) {
      state = state.copyWith(
        listening: false,
        error: 'Could not start listening: $e',
      );
    }
  }

  Future<void> stopListening() async {
    if (!state.listening) return;
    await _speech.stop();
    state = state.copyWith(listening: false);
  }

  Future<void> cancel() async {
    await _speech.cancel();
    state = state.copyWith(listening: false, recognized: '');
  }

  void _onResult(SpeechRecognitionResult result) {
    state = state.copyWith(recognized: result.recognizedWords);
  }

  void _onStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (state.listening) state = state.copyWith(listening: false);
    } else if (status == 'listening') {
      if (!state.listening) state = state.copyWith(listening: true);
    }
  }

  void _onError(SpeechRecognitionError err) {
    final msg = _humanize(err);
    state = state.copyWith(listening: false, error: msg);
  }

  String _humanize(SpeechRecognitionError err) {
    switch (err.errorMsg) {
      case 'error_permission':
      case 'error_audio':
        return 'Microphone permission denied. Enable mic access in system settings.';
      case 'error_no_match':
      case 'error_speech_timeout':
        return "Didn't catch that — try again.";
      case 'error_network':
      case 'error_network_timeout':
        return 'Network error during recognition.';
      case 'error_busy':
        return 'Speech recognizer is busy. Try again in a moment.';
      case 'error_language_not_supported':
      case 'error_language_unavailable':
        return 'Selected language is not installed on this device.';
      default:
        return err.errorMsg.isEmpty
            ? 'Speech recognition error.'
            : 'Speech error: ${err.errorMsg}';
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}

final sttProvider =
    StateNotifierProvider<SttNotifier, SttState>((ref) => SttNotifier());
