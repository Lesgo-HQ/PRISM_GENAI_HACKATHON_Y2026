import '../models/parsed_intent.dart';

class LocalIntentModel {
  static const Map<String, List<String>> _intentPatterns = {
    'search': [
      'find',
      'search',
      'look for',
      'show me',
      'where is',
      'search for',
      'get me',
      'i want',
      'i\'d like',
      'can you get',
      'look up',
    ],
    'add_to_cart': [
      'add',
      'cart',
      'put in',
      'basket',
      'add to bag',
      'buy this',
      'toss it in',
    ],
    'checkout': [
      'checkout',
      'pay',
      'buy now',
      'place order',
      'purchase',
      'proceed to pay',
    ],
    'filter': [
      'filter',
      'sort',
      'price under',
      'cheapest',
      'highest rating',
      'cheaper',
      'best',
    ],
    'teach': [
      'teach me',
      'show me how',
      'learn to',
      'record',
      'how to',
      'watch me',
    ],
  };

  static const List<String> _unknownPatterns = [
    'weather',
    'alarm',
    'timer',
    'music',
    'play',
    'call',
    'message',
    'text',
    'email',
    'navigate',
    'directions',
    'cab',
    'uber',
    'ola',
    'camera',
  ];

  static const List<String> _ambiguousPatterns = [
    'order pizza',
    'buy something',
    'get the usual',
    'order from the app',
    'get food',
    'do the thing',
  ];

  static const Map<String, List<String>> _appPatterns = {
    'swiggy': ['swiggy', 'instamart'],
    'blinkit': ['blinkit', 'blink it'],
    'myntra': ['myntra'],
    'zepto': ['zepto'],
    'amazon': ['amazon'],
    'flipkart': ['flipkart'],
  };

  Future<ParsedIntent> parse(String text) async {
    final lower = text.toLowerCase();

    // Check unknown first
    for (final pattern in _unknownPatterns) {
      if (lower.contains(pattern)) {
        return ParsedIntent.unknown(confidence: 0.9);
      }
    }

    // Check ambiguous
    for (final pattern in _ambiguousPatterns) {
      if (lower.contains(pattern)) {
        return ParsedIntent.ambiguous(slots: {}, confidence: 0.8);
      }
    }

    String? detectedApp;
    for (final entry in _appPatterns.entries) {
      for (final pattern in entry.value) {
        if (lower.contains(pattern)) {
          detectedApp = entry.key;
          break;
        }
      }
      if (detectedApp != null) break;
    }

    String bestIntent = 'UNKNOWN';
    double bestScore = 0.0;

    for (final entry in _intentPatterns.entries) {
      for (final pattern in entry.value) {
        if (lower.contains(pattern)) {
          // Simple scoring based on pattern length match
          double score = 0.6 + (pattern.length / lower.length) * 0.3;
          if (score > bestScore) {
            bestScore = score;
            bestIntent = entry.key;
          }
        }
      }
    }

    if (bestIntent == 'UNKNOWN') {
      return ParsedIntent.unknown(confidence: 0.4);
    }

    return ParsedIntent(
      intent: bestIntent,
      app: detectedApp,
      slots: {}, // Slots handled by SlotExtractor in SaarNlu
      confidence: bestScore.clamp(0.0, 1.0),
    );
  }

  Future<List<double>> embed(String text) async {
    // Stub for actual embeddings, returning zeroes
    return List.filled(128, 0.0);
  }
}
