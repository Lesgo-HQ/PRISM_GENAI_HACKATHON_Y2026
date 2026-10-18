# SAAR architecture

Flutter owns conversation, teaching lifecycle, storage, matching, replay and reports. Kotlin owns accessibility capture, guarded actions, speech and floating controls. The bridge uses saar/accessibility, saar/accessibility_events and saar/agent_controls.

Command → persisted trigger/example lookup → resolve slots → confirm → checkpoint → observe → ground → guard → act → verify → report.

Demonstration → native event buffer → normalization and deterministic compilation → SQLite workflow and defaults.

Requests without an exact saved match use the configured conversation model or the limited local fallback. Adaptive tasks use a separate bounded observe/plan/act/verify loop.

Exact learned commands and deterministic replay operate locally. Model conversation and adaptive planning send context to the user-configured server. Android speech recognition may need a network connection. No API key is required by the current local-server protocol; this does not imply all features work offline.

See [current architecture](current-architecture.md), [safety](safety.md), [limitations](limitations.md) and [requirements audit](requirements-audit-2026-10-18.md).
