import 'dart:ffi';
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Toggles Windows 11 Voice Typing (Win+H) by synthesizing the chord via
/// SendInput. Voice Typing then dictates into whatever TextField currently
/// holds focus — Flutter's text-input pipeline handles the rest, no plugin
/// callbacks required.
class WinVoiceTyping {
  const WinVoiceTyping._();

  static bool toggle() {
    if (!Platform.isWindows) return false;
    try {
      return _sendWinH();
    } catch (_) {
      return false;
    }
  }

  static bool _sendWinH() {
    const vkLWin = 0x5B;
    const vkH = 0x48;

    final inputs = calloc<INPUT>(4);
    try {
      // Win down
      final win0 = (inputs + 0).ref;
      win0.type = INPUT_KEYBOARD;
      win0.ki.wVk = vkLWin;
      win0.ki.dwFlags = 0;

      // H down
      final h0 = (inputs + 1).ref;
      h0.type = INPUT_KEYBOARD;
      h0.ki.wVk = vkH;
      h0.ki.dwFlags = 0;

      // H up
      final h1 = (inputs + 2).ref;
      h1.type = INPUT_KEYBOARD;
      h1.ki.wVk = vkH;
      h1.ki.dwFlags = KEYEVENTF_KEYUP;

      // Win up
      final win1 = (inputs + 3).ref;
      win1.type = INPUT_KEYBOARD;
      win1.ki.wVk = vkLWin;
      win1.ki.dwFlags = KEYEVENTF_KEYUP;

      final sent = SendInput(4, inputs, sizeOf<INPUT>());
      return sent == 4;
    } finally {
      calloc.free(inputs);
    }
  }
}
