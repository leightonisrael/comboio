import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Avisos que o piloto percebe sem olhar a tela: voz no capacete e vibração.
class FeedbackService {
  final FlutterTts _tts = FlutterTts();
  bool voiceEnabled = true;
  bool _ready = false;

  Future<void> init() async {
    try {
      await _tts.setLanguage('pt-BR');
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  Future<void> say(String text, {bool strong = false}) async {
    if (strong) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    if (!voiceEnabled || !_ready) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  void tick() => HapticFeedback.selectionClick();
}
