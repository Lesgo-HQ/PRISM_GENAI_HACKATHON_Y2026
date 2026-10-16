import '../models/ui_node.dart';

class CredentialGuard {
  /// Credential keywords matched as whole words only.
  ///
  /// A substring check is unusable here: "pin" occurs inside "shopping" and
  /// "spinner", so it would flag nearly every ordinary screen and abort the run.
  static final RegExp _sensitiveWord = RegExp(
    r'(^|[^a-z0-9])('
    r'password|passwd|otp|cvv|cvc|mpin|ssn|pin|'
    r'card[ _-]?number|card[ _-]?num|credit[ _-]?card|debit[ _-]?card|security[ _-]?code'
    r')($|[^a-z0-9])',
    caseSensitive: false,
  );

  /// Prompts that only appear on a credential entry screen.
  static const List<String> _sensitivePrompts = [
    'enter otp',
    'enter pin',
    'enter cvv',
    'enter cvc',
    'enter mpin',
    'enter password',
    'verify otp',
    'verification code',
    'one time password',
    'security code',
    'card number',
  ];

  /// Whether the given UI tree contains a credential entry field.
  ///
  /// Fail-closed: a missing or unreadable tree counts as sensitive. Callers
  /// that can distinguish "window mid-transition" from "unknown screen" should
  /// check for a null tree themselves before asking.
  static bool isSensitiveScreen(UiNode? rootNode) {
    if (rootNode == null) return true;
    try {
      return rootNode.flatten().any(_isSensitiveNode);
    } catch (_) {
      return true;
    }
  }

  static bool _isSensitiveNode(UiNode node) {
    if (_isPasswordInputType(node.inputType)) return true;

    if ((node.className ?? '').toLowerCase().contains('password')) return true;

    final identifiers = [
      node.resourceId ?? '',
      node.hintText ?? '',
      node.contentDescription ?? '',
    ];
    if (identifiers.any(_sensitiveWord.hasMatch)) return true;

    final text = (node.text ?? '').toLowerCase();
    return _sensitivePrompts.any(text.contains);
  }

  /// Android InputType class and variation masks.
  static const int _maskClass = 0x0000000F;
  static const int _maskVariation = 0x00000FF0;
  static const int _classText = 0x00000001;
  static const int _classNumber = 0x00000002;
  static const int _textVariationPassword = 0x00000080;
  static const int _textVariationVisiblePassword = 0x00000090;
  static const int _textVariationWebPassword = 0x000000E0;
  static const int _numberVariationPassword = 0x00000010;

  /// The variation must be read against the declared class: bare masking would
  /// flag `TYPE_TEXT_VARIATION_URI` and `TYPE_TEXT_VARIATION_PERSON_NAME`,
  /// which share bits with the number-password variation.
  static bool _isPasswordInputType(int inputType) {
    if (inputType == 0) return false;
    final variation = inputType & _maskVariation;
    final inputClass = inputType & _maskClass;

    if (inputClass == _classText || inputClass == 0) {
      if (variation == _textVariationPassword ||
          variation == _textVariationVisiblePassword ||
          variation == _textVariationWebPassword) {
        return true;
      }
    }
    if (inputClass == _classNumber || inputClass == 0) {
      if (variation == _numberVariationPassword) return true;
    }
    return false;
  }

  /// Describes why a screen was flagged, for the execution report.
  static String? getSensitiveReason(UiNode? rootNode) {
    if (rootNode == null) return 'No UI tree available (fail-closed)';
    try {
      for (final node in rootNode.flatten()) {
        if (_isSensitiveNode(node)) {
          return 'Sensitive field detected: '
              '${node.resourceId ?? node.className ?? node.text ?? 'unknown'}';
        }
      }
      return null;
    } catch (e) {
      return 'Error checking sensitivity: $e';
    }
  }
}
