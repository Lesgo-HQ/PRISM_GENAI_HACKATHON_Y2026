import '../models/action_trace_event.dart';

class SlotExtractor {
  Map<String, dynamic> extract(String text) {
    final lower = text.toLowerCase();
    final Map<String, dynamic> slots = {};

    final query = _extractQuery(lower);
    if (query != null) slots['query'] = query;

    final quantity = _extractQuantity(lower);
    if (quantity != null) slots['quantity'] = quantity;

    final app = extractApp(lower);
    if (app != null) slots['app'] = app;

    final variant = _extractVariant(lower);
    if (variant != null) slots['variant'] = variant;

    final restaurant = _extractRestaurant(lower);
    if (restaurant != null) slots['restaurant'] = restaurant;

    final category = _extractCategory(lower);
    if (category != null) slots['category'] = category;

    return slots;
  }

  String? _extractQuery(String text) {
    final match = RegExp(
      r'(search for|find|get me|buy|order) (.*?)( on | from |$)',
    ).firstMatch(text);
    return match?.group(2)?.trim();
  }

  dynamic _extractQuantity(String text) {
    if (text.contains('half kg')) return 0.5;
    if (text.contains('1.5 kg')) return 1.5;
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(kg|g|liters|ml|pcs|pack|items?)')
        .firstMatch(text);
    if (match != null) {
      return {
        'value': num.tryParse(match.group(1) ?? '1'),
        'unit': match.group(2),
      };
    }
    final numMatch = RegExp(r'\b(\d+)\b').firstMatch(text);
    return numMatch != null ? int.tryParse(numMatch.group(1)!) : null;
  }

  String? extractApp(String text) {
    const apps = ['swiggy', 'blinkit', 'myntra', 'zepto', 'amazon', 'flipkart'];
    for (final app in apps) {
      if (text.contains(app)) return app;
    }
    return null;
  }

  String? _extractVariant(String text) {
    final match = RegExp(
      r'\b(red|blue|black|white|small|medium|large|xl|xxl)\b',
    ).firstMatch(text);
    return match?.group(1);
  }

  String? _extractRestaurant(String text) {
    final match = RegExp(r'from (.*?) (on|$)').firstMatch(text);
    return match?.group(1)?.trim();
  }

  String? _extractCategory(String text) {
    const categories = [
      'electronics',
      'grocery',
      'fashion',
      'food',
      'medicines',
    ];
    for (final cat in categories) {
      if (text.contains(cat)) return cat;
    }
    return null;
  }

  List<String> getBioTags(String text) {
    // Stub for BIO token tagging
    final words = text.split(' ');
    return List.filled(words.length, 'O');
  }

  String redactSensitive(String text) {
    // Redact credit cards, passwords, etc.
    return text.replaceAll(
      RegExp(r'\b\d{4}-\d{4}-\d{4}-\d{4}\b'),
      '****-****-****-****',
    );
  }

  List<ActionTraceEvent> redactTrace(List<ActionTraceEvent> trace) {
    return trace.map((event) {
      final typed = event.valueTyped;
      if (typed == null || typed.isEmpty) return event;
      if (_isSensitive(typed)) {
        return ActionTraceEvent(
          timestampMs: event.timestampMs,
          action: event.action,
          node: event.node,
          valueTyped: '<REDACTED>',
          packageName: event.packageName,
        );
      }
      return event;
    }).toList();
  }

  bool _isSensitive(String value) {
    if (RegExp(r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b').hasMatch(value))
      return true;
    if (RegExp(r'\b\d{3}\b').hasMatch(value) && value.length <= 4) return true;
    final lower = value.toLowerCase();
    const sensitive = [
      'password',
      'passwd',
      'otp',
      'pin',
      'cvv',
      'cvc',
      'secret',
      'token',
    ];
    return sensitive.any(lower.contains);
  }
}
