# SAAR agent architecture

SAAR is a Flutter/Dart application with a native Kotlin Android bridge. Its conversation, teaching, replay and adaptive execution share app state and local SQLite storage.

## Runtime responsibilities

| Module | Responsibility |
|---|---|
| `app_controller.dart` | Conversation, app selection, task approval, interruptions and lifecycle |
| `conversation_service.dart` | Typed intent decisions, learned-skill selection and compatibility verification |
| `adaptive_agent.dart` | Observe, plan one action, validate its target, dispatch, verify and checkpoint |
| `action_verifier.dart` | Assess success, wrong-page results, unchanged screens or uncertainty |
| `screen_observer.dart` | Wait for slow transitions with bounded observation retries; focus movement alone is not navigation |
| `memory_context.dart` | Build scoped user/app context and exclude blank or oversized UTF-8 blocks |
| `flow_store.dart` | Persist skills, task checkpoints, memory and execution history |
| `replay_engine.dart` | Execute demonstrated workflows with parameter substitution and manual handoff |
| Kotlin accessibility service | Observe visible elements, dispatch guarded gestures and display task controls |

All services are application code under `lib/services/`. Builds need no reference checkout, source snapshot or separate upstream application.

## Execution rules

An adaptive task is approved for one app and bounded to 30 dispatched actions per run. Each proposal refers to the current observation's indexed elements; a changed screen invalidates the proposal. Checkpoints are saved before actions. Interrupted or uncertain actions require human review instead of automatic repetition.

After dispatch, screen capture waits for a bounded transition interval. If a screen remains unchanged it is observed again after 500ms and 1000ms, without replaying the action. Missing and sensitive screens remain unverifiable. The action verifier assesses the observed outcome; completion separately requires visible evidence and a goal-completion check.

Pause, Resume, Talk and Stop are available in the native capsule. User updates can revise a paused goal. Scoped memory supplies relevant context without becoming executable instructions.

## Current boundaries

- Accessibility trees are used, not screenshot VLM reasoning; canvas-only apps may be unusable.
- Model inference uses the configured server; no language-model weights ship inside the APK.
- One verified goal summary per app is retained; this is not a semantic memory search engine.
- Speech is push-to-talk with TTS interruption, not continuous listening.
- One adaptive task cannot autonomously switch to another approved app.
- Model verification can be wrong. Typed responses and execution checks reduce but do not eliminate mistakes.
- Native gestures, overlays, permissions, voice and real-app success still require Android device or emulator testing.

Reused source attribution and licenses are recorded in [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
