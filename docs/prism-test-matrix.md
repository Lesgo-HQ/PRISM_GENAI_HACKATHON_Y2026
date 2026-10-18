# PRISM test matrix

Status distinguishes host simulations from physical evidence. No row represents a complete physical PASS merely because code exists.

| ID | Scenario | Current evidence / remaining verification |
|---|---|---|
| T1 | Teach food workflow | User's existing food workflows persisted. Fresh native capture/save tested with reversible Settings navigation; full food demonstration remains unverified. |
| T2 | Exact replay | Existing Swiggy command physically resolves to confirmation after the fix. Its old manual-only first step pauses for help. Full food replay remains unverified. |
| T3 | Paraphrase | Live qwen2.5:3b catalog-search paraphrase selected the correct skill; full physical food paraphrases remain unverified. |
| T4 | Item slot | Live changed search parameters and host slot binding tests pass; physical food item substitution remains unverified. |
| T5 | Quantity slot | Host basic word/numeric extraction covered. Arbitrary quantity-stepper compilation remains incomplete. |
| T6 | Address slot | Host basic address extraction covered. Physical address-selector substitution remains unverified. |
| T7 | Changed screen/popup | Bounded recovery implemented and host observations covered; physical popup matrix remains unverified. |
| T8 | Teach ecommerce | Separate workflow persistence supported. Full ecommerce physical demonstration remains unverified. |
| T9 | Cross-app transfer | Not demonstrated; app-specific replay must not be represented as cross-app transfer. |
| T10 | Stuck/clarify/resume | Host checkpoint/manual-boundary tests and physical old-flow manual pause observed. Full same-step physical recovery matrix remains unverified. |
| T11 | Credentials/payment | Host guards and native build verified. Custom/localized/financial-app device matrix remains unverified. |
| T12 | Unknown intent | Host tests plus live unsupported transfer/travel rejected by deterministic operation checks. |
| T13 | Ambiguity | Host duplicate exact triggers and numbered selection covered; broad physical ambiguity matrix remains unverified. |
| T14 | Reporting | SQLite reporting implementation and host tests exist; full physical report accuracy matrix remains unverified. |

See [requirements audit](requirements-audit-2026-10-18.md) and [current verification](verification-2026-10-18.md).
