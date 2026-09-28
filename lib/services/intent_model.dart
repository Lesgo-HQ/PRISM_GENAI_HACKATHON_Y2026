import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;

import '../models/parsed_intent.dart';
import 'slot_extractor.dart';

class LocalIntentModel {
  static const MethodChannel _channel = MethodChannel('saar/accessibility');
  static const int _embeddingSize = 128;
  final Map<String, int> _vocab = {};
  final SlotExtractor _slotExtractor = SlotExtractor();

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

  Future<ParsedIntent> parse(String text) async {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) return ParsedIntent.unknown();

    final intent = switch (true) {
      _ when lower.contains('teach') => 'teach',
      _ when lower.contains('search') || lower.contains('find') => 'search',
      _ when lower.contains('order') || lower.contains('buy') => 'order',
      _ when lower.contains('add') && lower.contains('cart') => 'add_to_cart',
      _ when lower.contains('checkout') || lower.contains('pay') => 'checkout',
      _ when lower.contains('quantity') || lower.contains('how many') => 'change_quantity',
      _ when lower.contains('address') => 'select_address',
      _ when lower.contains('filter') => 'filter',
      _ when lower.contains('sort') => 'sort',
      _ => null,
    };
    if (intent == null) return ParsedIntent.unknown();

    return ParsedIntent(
      intent: intent,
      app: _slotExtractor.extractApp(lower),
      slots: _slotExtractor.extract(text),
      confidence: 0.9,
      embedding: await embed(text),
    );
  }

  Future<List<double>> embed(String text) async {
    final vector = List<double>.filled(_embeddingSize, 0);
    for (final token in text.toLowerCase().split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      var hash = 2166136261;
      for (final codeUnit in token.codeUnits) {
        hash = ((hash ^ codeUnit) * 16777619) & 0x7fffffff;
      }
      vector[hash % _embeddingSize] += 1;
    }
    final magnitude = vector.fold<double>(0, (sum, value) => sum + value * value);
    if (magnitude == 0) return vector;
    final scale = 1 / math.sqrt(magnitude);
    return vector.map((value) => value * scale).toList();
  }
}
