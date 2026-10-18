# Safety boundaries

Dart CredentialGuard and the Kotlin accessibility service independently inspect field metadata, input types and explicit credential/payment labels. Unreadable screens block replay. Payment confirmation, credentials and destructive actions require manual control; model confidence cannot override these checks.

The native recorder redacts recognized sensitive node text and typed values. The compiler turns recognized sensitive or unreadable targets into stop_before steps without saving their target text. Card-number-like typed values are redacted. This is heuristic protection, not a guarantee that all PII or custom sensitive interfaces are detected.

For tappable containers, a bounded child subtree is captured so labels can identify the recorded row. Sensitive child nodes remain redacted, and the compiler checks the subtree before retaining an action.

Every replay action is checkpointed before dispatch. An unverified dispatched action is not blindly repeated. Pause/Stop and manual acknowledgement preserve control. Exact saved command selection also requires confirmation before execution.

Native and Dart guards cover explicit password/OTP/PIN/card prompts, plain credential labels and payment labels such as Pay, Pay now, Place order and Confirm purchase. Custom WebViews, localized labels, biometric flows and weak metadata still require adversarial device validation.

Do not claim full payment/credential safety based on host tests alone. See [limitations](limitations.md) and the dated verification report.
