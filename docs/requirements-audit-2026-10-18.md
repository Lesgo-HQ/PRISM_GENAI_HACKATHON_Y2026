# Requirements audit — 2026-10-18

Reviewed every project Markdown file: README, PLAN, THIRD_PARTY_NOTICES, all eight existing documents under docs, and the dataset/model READMEs. PLAN is the broad product/submission backlog; its offline-neural target differs from the currently configured server-assisted app. The user's current local endpoint remains supported.

| Requirement group | Implementation and remaining work |
|---|---|
| Teach once, save, exact reuse | Native capture, deterministic compiler and SQLite exist. Fixed controller bypass of exact matching, punctuation/example lookup, duplicate ambiguity, index-independent reuse, stop/save/cancel lifecycle and recovery metadata consumption. |
| Natural conversation and model endpoints | Structured protocol and compatibility verification exist. Exact reuse bypasses the model. A passing connectivity probe is not a routing-quality test. Live model results are recorded separately. |
| Paraphrases and unknown requests | Model-assisted selection and conservative fallback exist. No calibrated semantic retrieval or comprehensive false-execution benchmark. |
| Slots: item, quantity, address | Declared slots/defaults and replay substitution exist; basic word quantities/address extraction added. Arbitrary quantity stepper loops, address-selector generalization and multiple independent text fields need further work. |
| Accessibility and grounding | Native observations/actions and semantic/identity ranking exist. Fixed grounding for non-clickable scroll containers. Structural/history scoring and app redesign robustness remain limited. |
| Replay state, stuck/resume and stop | Checkpointed execution, bounded recovery, pause, same-step resume and uncertain-action review exist with host tests. Full physical interruption matrix remains outstanding. |
| Preconditions/postconditions | Schema and runtime checks exist. Compiler does not infer full before/after semantic postconditions from demonstrations; generic screen change is used when explicit conditions are absent. |
| Recovery and incidental actions | Safe popup/scroll recovery and system/launcher filtering exist. Full causal filtering of unrelated actions and cross-app interruptions is not implemented. |
| Credential/payment boundary | Independent Dart/native guards, redaction and manual boundaries exist. Added plain credential/payment label coverage. Custom WebView/localized adversarial device testing remains outstanding. |
| Reporting | Persisted execution reports/statistics and report UI exist. Full physical T14 evidence remains outstanding. |
| On-device neural NLU | Experimental assets/tooling exist; deployed parsing remains rules/hash based. Validated multi-head training, distillation, BIO decoding, neural embeddings and calibrated unknown detection are not complete. |
| Offline and resource targets | No runtime API key required. Server-assisted conversation is not on-device inference. Offline ASR, low/mid/high device benchmarks, memory/latency/power measurements remain outstanding. |
| Cross-app transfer | App-specific learned replay exists. General semantic transfer is not proven and must not be described as passing T9. |
| Delivery and submission | Build/test commands, architecture and license assets exist. Production signing, full clean-install/device matrix and ≤5-minute unedited demonstration remain outstanding. |

This audit does not mark every PLAN checkbox complete. A trained/evaluated neural model, real-app success and physical evidence cannot be substituted with passing unit tests or the existence of a class. See the dated verification report for checks actually run in this session.
