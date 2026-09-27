class ParsedIntent {
  final String intent;
  final String? app;
  final Map<String, dynamic> slots;
  final double confidence;
  final bool isAmbiguous;
  final List<double>? embedding;

  const ParsedIntent({
    required this.intent,
    this.app,
    required this.slots,
    required this.confidence,
    this.isAmbiguous = false,
    this.embedding,
  });

  factory ParsedIntent.unknown({double confidence = 0}) =>
      ParsedIntent(intent: 'UNKNOWN', slots: const {}, confidence: confidence);

  factory ParsedIntent.ambiguous({
    required Map<String, dynamic> slots,
    double confidence = 0.5,
  }) => ParsedIntent(
    intent: 'AMBIGUOUS',
    slots: slots,
    confidence: confidence,
    isAmbiguous: true,
  );

  bool get isUnknown => intent == 'UNKNOWN';

  Map<String, dynamic> toJson() => {
    'intent': intent,
    if (app != null) 'app': app,
    'slots': slots,
    'confidence': confidence,
    'is_ambiguous': isAmbiguous,
  };

  factory ParsedIntent.fromJson(Map<String, dynamic> j) => ParsedIntent(
    intent: j['intent'] as String,
    app: j['app'] as String?,
    slots: Map<String, dynamic>.from(j['slots'] as Map? ?? {}),
    confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
    isAmbiguous: j['is_ambiguous'] as bool? ?? false,
  );
}
