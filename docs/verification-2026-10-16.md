# Verification — 2026-10-16

Local verification of the SAAR agent implementation:

| Check | Result |
|---|---|
| `flutter analyze` | Passed, no issues |
| `SAAR_LIVE_MODEL=1 flutter test` | 58 tests passed, no skips |
| `flutter build apk --debug` | Passed; `build/app/outputs/flutter-apk/app-debug.apk` |
| `git diff --check` | Passed |

The live test used llama.cpp with Qwen/Qwen3-4B-GGUF Q4_K_M, alias `local`, context 8192 and reasoning budget 0. It checks two unseen search parameters, two conversational requests, two unsupported actions, and the action verifier against successful and wrong-page observations. The model returned A for the successful search and B for the wrong page. Earlier evaluation runs failed; the final checks followed schema, reusable-parameter and operation-compatibility fixes. Passing this small routing test does not establish general agent quality or conversational quality.

Adaptive execution tests use simulated accessibility trees and model responses. They cover target/action rejection, observation/action/reflection, cancellation during inference, stale targets, unsupported completion claims, pending-action recovery and prevention of repeated attempts. The native build confirms compilation, not runtime behavior.

No Android device or emulator was available. Real gestures, overlay interactions, voice permissions, credential detection on custom app UIs, and task completion across real applications remain unverified. No production-readiness or upstream feature-parity claim is made.

The temporary model server used for evaluation was stopped afterward. The README contains the restart command; downloaded weights remain in the local model cache.

## Integration verification

- Original source snapshots were checksum-checked during integration; duplicate snapshots were subsequently removed from the application codebase.
- Both full license files and the unchanged ClosePaw NOTICE were verified inside the built APK.
- Additional regressions cover slow transitions, bounded capture attempts, focus-only changes, missing/sensitive screens, cancellation during settling, UTF-8 memory limits and strict reflection outcome parsing.
- Action verification, screen observation and memory context are integrated services under `lib/services/`. Research clones were moved outside the application workspace.

## SAAR module consolidation

After moving the implementation into `action_verifier.dart`, `screen_observer.dart` and `memory_context.dart`, static analysis passed and the host suite passed 56 tests. The two opt-in live-model tests were skipped in this structural-refactor run; their preceding successful results are recorded above. No inference protocol or execution behavior was changed in the consolidation.
