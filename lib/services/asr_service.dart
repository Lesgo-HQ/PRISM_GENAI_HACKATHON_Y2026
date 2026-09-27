import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

class AsrService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) => debugPrintAsr('ASR Error: $error'),
      onStatus: (status) => debugPrintAsr('ASR Status: $status'),
    );
    return _isInitialized;
  }

  /// Listen once and return the final transcript.
  /// Push-to-talk: starts listening, returns a Future that completes
  /// when the user stops speaking or timeout.
  Future<String?> listenOnce({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        return null;
      }
    }

    final completer = Completer<String?>();
    String? finalResult;

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          finalResult = result.recognizedWords;
          if (!completer.isCompleted) {
            completer.complete(finalResult);
          }
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: false,
        autoPunctuation: true,
      ),
    );

    // Timeout fallback mechanism
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        _speech.stop();
        completer.complete(finalResult);
      }
    });

    return completer.future;
  }

  /// Stop listening immediately
  Future<void> stopListening() async {
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized;
}

void debugPrintAsr(String message) {
  // ignore: avoid_print
  // Using print here intentionally for ASR debugging in development
  assert(() {
    // ignore: avoid_print
    print(message);
    return true;
  }());
}
