import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

class AsrService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  String? _lastError;
  String? _localeId;

  String? get lastError => _lastError;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          _lastError = error.errorMsg;
          debugPrint('ASR Error: ${error.errorMsg} (permanent: ${error.permanent})');
        },
        onStatus: (status) => debugPrint('ASR Status: $status'),
        debugLogging: false,
      );
      if (!_isInitialized) {
        _lastError = 'Speech recognition is unavailable on this device.';
      } else {
        await _selectLocale();
      }
    } catch (e) {
      _lastError = '$e';
      _isInitialized = false;
    }
    return _isInitialized;
  }

  /// Picks a locale the installed recognizer actually has a model for.
  ///
  /// The device default can be a regional variant (en_IN) that an on-device
  /// recognizer has no downloaded model for, in which case it ends the session
  /// immediately with no result. An English variant that is listed is safer.
  Future<void> _selectLocale() async {
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) {
        debugPrint('ASR: recognizer reports no installed locales');
        return;
      }
      debugPrint('ASR locales: ${locales.map((l) => l.localeId).join(', ')}');

      final system = await _speech.systemLocale();
      final preferred = [
        if (system != null) system.localeId,
        'en_US',
        'en_IN',
        'en_GB',
      ];
      for (final candidate in preferred) {
        final match = locales.where((l) => l.localeId == candidate);
        if (match.isNotEmpty) {
          _localeId = match.first.localeId;
          return;
        }
      }
      final english = locales.where((l) => l.localeId.startsWith('en'));
      if (english.isNotEmpty) _localeId = english.first.localeId;
    } catch (e) {
      debugPrint('ASR locale selection failed: $e');
    }
  }

  Future<bool> ensureMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _lastError = 'Microphone permission denied.';
        return false;
      }
      return true;
    } catch (e) {
      _lastError = '$e';
      return false;
    }
  }

  /// Listens until the speaker stops, then returns the best transcript.
  ///
  /// The recognizer is treated as finished on either a final result or a
  /// terminal status callback. Partial results are kept as a fallback because
  /// several Android recognizers deliver a usable transcript only as a partial
  /// and then end the session without emitting a final result.
  Future<String?> listenOnce({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    _lastError = null;

    if (!await ensureMicrophonePermission()) return null;
    if (!_isInitialized && !await initialize()) return null;

    if (_speech.isListening) {
      await _speech.stop();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }

    final completer = Completer<String?>();
    String? bestTranscript;
    Timer? timeoutTimer;

    void finish() {
      timeoutTimer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(bestTranscript?.trim());
      }
    }

    try {
      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          if (result.recognizedWords.isNotEmpty) {
            bestTranscript = result.recognizedWords;
          }
          if (result.finalResult) finish();
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          listenFor: timeout,
          pauseFor: const Duration(seconds: 3),
          localeId: _localeId,
        ),
      );
    } catch (e) {
      _lastError = '$e';
      return null;
    }

    // The plugin flips isListening to false on 'done'/'notListening' as well as
    // on error, so polling covers every way the session can end.
    Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (completer.isCompleted) {
        timer.cancel();
        return;
      }
      if (!_speech.isListening) {
        timer.cancel();
        // Give a trailing final result a moment to arrive.
        Future<void>.delayed(const Duration(milliseconds: 600), finish);
      }
    });

    timeoutTimer = Timer(timeout + const Duration(seconds: 2), () async {
      await stopListening();
      finish();
    });

    final transcript = await completer.future;
    if (transcript == null || transcript.isEmpty) {
      _lastError ??=
          'No speech recognised. Tap "Type a command instead" to continue.';
      return null;
    }
    return transcript;
  }

  Future<void> stopListening() async {
    try {
      if (_speech.isListening) await _speech.stop();
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      if (_speech.isListening) await _speech.cancel();
    } catch (_) {}
  }

  bool get isListening => _speech.isListening;
  bool get isAvailable => _isInitialized;
}
