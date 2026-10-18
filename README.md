# SAAR — teachable Android assistant

SAAR combines demonstrated workflows with a model-driven Android agent. Flutter/Dart owns conversation, typed decisions, task state and local storage; Kotlin owns accessibility observations, gestures, speech and the floating task controls.

## What is implemented

- **Teach and reuse:** record a demonstration, compile an app-specific procedure, substitute declared parameters and verify each replay step.
- **Operate an app:** enter `do <goal>`, select an installed app and approve the task. The agent observes the accessibility tree, proposes one action, validates its current target, acts, and checks the result before continuing.
- **Conversation:** a configured local model answers questions and selects learned skills with structured responses. Skill selection is checked separately before execution.
- **Interruptions:** Pause, Resume, Talk and Stop are available in a floating accessibility capsule. Updated instructions are incorporated when a paused task resumes.
- **Recovery:** SQLite checkpoints are written before actions. Interrupted or uncertain actions require review; they are not silently replayed after restart.
- **Memory:** `remember <preference>` stores explicit user preferences; `forget my preferences` clears them. Successfully verified adaptive goals are retained as app-specific context.

This is an implementation under device validation, not a claim that arbitrary Android apps already work reliably. See [agent architecture and current boundaries](docs/agent-architecture.md).

## Build

Use Flutter with Dart compatible with `pubspec.yaml` (Dart 3.13.4 or newer), the Android SDK and a compatible JDK. This checkout was built using Flutter 3.47.7, JDK 24 and Android compile SDK 37.

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The APK is generated at `build/app/outputs/flutter-apk/app-debug.apk`. Install on an Android device, enable SAAR in Android Accessibility settings, and allow microphone access for voice input. Typed input also works. No `.env` or paid API key is required.

## Local model setup

Conversation and adaptive planning need an OpenAI-compatible server that supports JSON-schema constrained responses. The deterministic intent fallback is limited; it is not an on-device language model.

One tested local setup uses llama.cpp and Qwen3-4B GGUF:

```sh
llama-server -hf Qwen/Qwen3-4B-GGUF:Q4_K_M \
  --host 127.0.0.1 --port 8080 --ctx-size 8192 \
  --alias local --jinja --reasoning-budget 0
```

The first run downloads model weights. In SAAR Settings, enable the model, set model name `local`, and test the connection. Use the endpoint appropriate to your connection:

| Connection | Endpoint |
|---|---|
| Android emulator | `http://10.0.2.2:8080/v1/chat/completions` |
| USB device after `adb reverse tcp:8080 tcp:8080` | `http://127.0.0.1:8080/v1/chat/completions` |
| Other server | A trusted HTTPS endpoint supporting this protocol |

HTTP is allowed only for local development addresses. This configuration runs inference on the computer, not on the Android phone. Screen observations and conversation context are sent to the configured endpoint; choose one you control. No cloud fallback is silently enabled.

The 4B model passed the six-case live routing check after prompt/schema fixes, but also made incorrect proposals during development. Schema validation does not guarantee semantic correctness. Compatibility checks, action validation, result checks and human handoff remain necessary.

## Reusing skills with different wording

Saved skills are matched by intended outcome, app and declared inputs. With the model enabled, requests can use synonyms, indirect phrasing or Hindi/Hinglish; recent conversation is included when resolving follow-up answers. Android supplies app names dynamically, so this is not limited to a fixed list of brands. A second structured assessment checks the proposed procedure before confirmation. Ambiguous app choices ask a question; plausible matches show the saved workflow and inputs for review. Exact demonstrated commands also work without model routing.

A saved procedure remains specific to its app: teaching one food app does not establish that the same gestures work in another. Language accuracy depends on the configured model. Without it, non-exact matching uses a limited lexical fallback, not equivalent multilingual understanding.

## If the app opens and then appears stuck

`flutter run` starts the Android app, not the AI server. For adaptive tasks, start the model server described above, connect the phone to that computer by USB, and run:

```sh
adb reverse tcp:8080 tcp:8080
flutter run
```

In SAAR Settings, enable the AI model, set endpoint `http://127.0.0.1:8080/v1/chat/completions` and model name `local`, then use **Save & test connection**. It must report that structured responses work. Port forwarding needs to be restored after reconnecting the phone. A phone on a different computer cannot use the original developer's loopback server.

SAAR checks model connectivity before opening an app and waits for a readable target screen after launch. If it pauses, read the status in the floating controls or return to SAAR; missing accessibility access, an unreachable model and manual sign-in each need different handling.

## Try the workflows

1. Start with a reversible task such as searching a catalog or navigating Settings.
2. For an unseen task, choose **Operate an app**, enter the goal after `do`, choose an app and explicitly approve it.
3. For a demonstration, choose **Teach a skill** and describe the task after `teach me to`. Perform the workflow in the target app, then return and stop/save the recording.
4. Request the learned task with a different declared parameter. Confirm the proposed replay.
5. Use Pause or Talk to intervene. Complete requested manual steps yourself and continue. Use Stop to cancel.

Sign-in, credentials and consequential actions require manual control. Screen protection uses accessibility metadata and heuristics, so it needs validation against actual apps; do not assume every sensitive custom UI is detected.

## Verification

```sh
flutter analyze
flutter test
# Requires the local server above; otherwise this test is skipped:
SAAR_LIVE_MODEL=1 flutter test test/model_live_test.dart
```

Host tests cover conversation decisions, confirmations, workflow replay, checkpoints, stale targets, cancellation and completion evidence. They simulate accessibility observations. Android speech, overlays, permissions, real gestures and task success across actual apps require device testing; no device or emulator was available during this work.

SAAR’s execution, verification and memory services live directly in `lib/services/`. Source attribution and licenses are documented in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Code guide

- `lib/app_controller.dart`: conversation and task lifecycle.
- `lib/services/conversation_service.dart`: typed skill selection and compatibility verification.
- `lib/services/adaptive_agent.dart`: bounded observe/plan/act/reflect loop.
- `lib/services/replay_engine.dart`: demonstrated workflow execution.
- `lib/services/flow_store.dart`: SQLite flows, checkpoints, memory and history.
- `lib/models/agent_task.dart`: observations, validated actions and persisted tasks.
- `android/app/src/main/kotlin/com/lesgo/saar/`: Android bridge and accessibility service.
- `ml/`: experimental NLU training pipeline; it is not evidence of a deployed neural runtime.

The existing submission presentation and video are historical artifacts. Older design documents describe goals and may differ from current verified behavior; this README and the agent architecture document describe this implementation.
