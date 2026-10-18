# Current architecture

See [agent architecture](agent-architecture.md) for runtime ownership and [requirements audit](requirements-audit-2026-10-18.md) for implementation and verification gaps.

Commands first check persisted exact triggers and saved examples, ignoring case, repeated whitespace and terminal speech punctuation. A match uses demonstrated slot defaults and requires confirmation. Duplicate triggers require choosing a workflow. This path needs neither an embedding index nor a model server.

Other requests use the configured model with structured decisions and separate compatibility verification. When the model is disabled, a limited keyword/hash matcher is available; incompatible operations and explicitly different apps are excluded. This is not a trained semantic NLU runtime.

Teaching uses the native accessibility event buffer, a deterministic trace normalizer/compiler, and SQLite persistence. The UI acknowledges saving only after the flow is committed. Search-index failures do not hide saved workflows. Stop recording saves; cancelling discards the capture. Sensitive or unreadable recorded targets become manual steps and are disclosed in the save message.

Replay uses semantic/identity grounding, live safety checks, checkpoints before dispatch, result observations and explicit clarification. A changed screen is a limited completion heuristic for steps without explicit postconditions. Native compilation and host tests do not establish successful replay in every third-party app.
