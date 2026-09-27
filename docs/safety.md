# SAAR Safety Documentation

## Dual-Layer Credential Guard
SAAR implements a rigorous Dual-Layer Credential Guard to prevent unintentional interaction with sensitive data.

### Flutter Layer (Pre-flight & Real-time)
`CredentialGuard.isSensitiveScreen` evaluates the screen snapshot. It checks:
- `inputType` (e.g., password types)
- `resourceId`
- `className`
- `hintText`
- `contentDescription`
- `text`
If any matches a blocklist, the execution fails closed.

### Kotlin Layer (Execution time)
`SaarAccessibilityService.isSensitiveScreenDetected` runs the exact same checks on the native side immediately before dispatching an accessibility gesture.

## Fail-Closed Behavior
In any ambiguous state (e.g., a null tree, text extraction failure, or an unknown regex error), the system assumes the screen is sensitive and will fail closed (return `false`), preventing execution.

## Payment Boundary
Payment gateways and financial transactions are strictly outside the automation boundary. A `stop_before` action is injected for payment/credential roles in the `FlowCompiler`. This prevents any automated confirmation of payments.

## Trace Redaction
During `RECORDING`, `SlotExtractor.redactTrace` automatically redacts sensitive trace content. It removes:
- Credit card numbers
- Short PINs
- Sensitive keywords
This ensures that the final saved abstract flow contains no user PII.

## What is Never Automated
- Settings changes (unless explicitly a SAAR-approved flow).
- Password inputs.
- Bank transfers.
- Deletion of accounts/data.
