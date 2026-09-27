import 'package:flutter/services.dart';
import 'dart:convert';

class LocalIntentModel {
  static const MethodChannel _channel = MethodChannel('saar/accessibility');
  Map<String, int> _vocab = {};

  Future<void> initialize() async {
    try {
      final vocabString = await rootBundle.loadString('assets/models/vocab.txt');
      final lines = const LineSplitter().convert(vocabString);
      for (int i = 0; i < lines.length; i++) {
        _vocab[lines[i].trim()] = i;
      }
    } catch (e) {
      print("Failed to load vocab.txt: $e");
    }
  }

  Future<List<double>?> predictIntent(String text) async {
    // 1. Basic whitespace tokenization
    final tokens = text.toLowerCase().split(RegExp(r'\s+'));
    
    // 2. Map to IDs using vocab (101 is CLS, 102 is SEP, 100 is UNK)
    List<int> inputIds = [101]; // CLS
    for (final token in tokens) {
      if (token.isEmpty) continue;
      inputIds.add(_vocab[token] ?? 100); // UNK if not found
    }
    inputIds.add(102); // SEP
    
    // 3. Pad to 64
    if (inputIds.length > 64) {
      inputIds = inputIds.sublist(0, 64);
      inputIds[63] = 102;
    }
    List<int> mask = List.filled(inputIds.length, 1);
    while (inputIds.length < 64) {
      inputIds.add(0); // PAD
      mask.add(0);
    }

    // 4. Send to Kotlin
    try {
      final List<dynamic>? logits = await _channel.invokeMethod('predictIntent', {
        'inputIds': inputIds.map((e) => e.toDouble()).toList(),
        'attentionMask': mask.map((e) => e.toDouble()).toList(),
      });
      return logits?.cast<double>();
    } catch (e) {
      print("Failed to run ONNX model: $e");
      return null;
    }
  }
}
