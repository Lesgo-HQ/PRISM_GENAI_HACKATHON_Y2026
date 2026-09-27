import '../models/ui_node.dart';

class CredentialGuard {
  /// Check if the current UI tree contains any sensitive fields.
  /// This is FAIL-CLOSED: if anything goes wrong, returns true (sensitive detected).
  static bool isSensitiveScreen(UiNode? rootNode) {
    if (rootNode == null) return true; // fail closed
    try {
      final allNodes = rootNode.flatten();
      return allNodes.any((node) => _isSensitiveNode(node));
    } catch (_) {
      return true; // fail closed
    }
  }

  static bool _isSensitiveNode(UiNode node) {
    // Check inputType flags for password variants
    final inputType = node.inputType;
    final maskedVariation = inputType & 0xFF0;
    const passwordVariations = [0x80, 0x90, 0xE0, 0x10];
    if (passwordVariations.contains(maskedVariation)) return true;

    // Check resourceId patterns (case-insensitive)
    final rid = (node.resourceId ?? '').toLowerCase();
    const sensitiveIdPatterns = [
      'password',
      'passwd',
      'otp',
      'verification',
      'pin',
      'mpin',
      'cvv',
      'cvc',
      'card_number',
      'credit_card',
      'debit_card',
      'security_code',
      'card_num',
      'bank_account',
      'upi',
      'ifsc',
      'payment',
      'pay_now',
      'place_order',
      'confirm_purchase',
      'biometric',
    ];
    if (sensitiveIdPatterns.any((p) => rid.contains(p))) return true;

    // Check className
    final cn = (node.className ?? '').toLowerCase();
    if (cn.contains('password')) return true;

    // Check hint text
    final hint = (node.hintText ?? '').toLowerCase();
    if (sensitiveIdPatterns.any((p) => hint.contains(p))) return true;

    // Check contentDescription
    final cd = (node.contentDescription ?? '').toLowerCase();
    const sensitiveDescPatterns = [
      'password',
      'passwd',
      'otp',
      'verification code',
      'pin',
      'mpin',
      'cvv',
      'cvc',
      'card number',
      'credit card',
      'debit card',
      'bank account',
      'upi',
      'ifsc',
      'payment',
      'pay now',
      'place order',
      'confirm purchase',
      'biometric confirmation',
      'confirm payment',
      'complete purchase',
      'authorize',
      'send money',
      'transfer funds',
    ];
    if (sensitiveDescPatterns.any((p) => cd.contains(p))) return true;

    // Check text (for login screens)
    final text = (node.text ?? '').toLowerCase();
    const loginPatterns = [
      'enter otp',
      'enter pin',
      'enter mpin',
      'enter cvv',
      'enter cvc',
      'enter password',
      'verify otp',
      'verification code',
      'card number',
      'bank account',
      'upi',
      'ifsc',
      'payment',
      'pay now',
      'place order',
      'confirm purchase',
      'biometric confirmation',
      'login',
      'sign in',
      'confirm payment',
      'complete purchase',
      'authorize',
      'send money',
      'transfer funds',
    ];
    if (loginPatterns.any((p) => text.contains(p)) ||
        (text.contains('total') && text.contains('pay')))
      return true;

    return false;
  }

  /// Returns a description of why the screen was flagged as sensitive
  static String? getSensitiveReason(UiNode? rootNode) {
    if (rootNode == null) return 'No UI tree available (fail-closed)';
    try {
      final allNodes = rootNode.flatten();
      for (final node in allNodes) {
        if (_isSensitiveNode(node)) {
          return 'Sensitive field detected: ${node.resourceId ?? node.className ?? node.text ?? 'unknown'}';
        }
      }
      return null;
    } catch (e) {
      return 'Error checking sensitivity: $e';
    }
  }
}
