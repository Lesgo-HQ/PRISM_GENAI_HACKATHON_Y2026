# Third-party notices

SAAR's implementation includes modified code derived from the following open-source projects. These are integrated SAAR modules; no upstream checkout or separate upstream runtime is required to build or run the app.

| SAAR module | Source and changes | License |
|---|---|---|
| `lib/services/action_verifier.dart` | Roubao `ActionReflector.kt`; translated to Dart, accessibility observations, strict JSON validation and an explicit uncertain outcome. | MIT, copyright (c) 2025 Roubao Team |
| `lib/services/screen_observer.dart` | ClosePaw `PostActionAnalysis.kt` and `UiChangeDetector.kt`; Dart adaptation for bounded observation retries, focus-independent change checks, cancellation and credential checks. | Apache-2.0, copyright 2026 ClosePaw Authors |
| `lib/services/memory_context.dart` | ClosePaw `MemoryRecaller.kt`; Dart adaptation for SQLite user/app context and bounded UTF-8 recall. | Apache-2.0, copyright 2026 ClosePaw Authors |

Sources:
- [Roubao](https://github.com/Turbo1123/roubao/tree/c8a6d7f03422eb01744b01f3ee77bf7757741f7e), commit `c8a6d7f03422eb01744b01f3ee77bf7757741f7e`.
- [ClosePaw](https://github.com/imoonkey/closepaw/tree/75dae2653f5a6b25d5df51ee7008b0f830de1536), commit `75dae2653f5a6b25d5df51ee7008b0f830de1536`.

Full licenses and ClosePaw's unchanged NOTICE are in `assets/licenses/`, bundled in the APK and available through Settings → Open source licenses. Modification and copyright notices are retained in the affected source files.

ClosePaw's NOTICE describes its own dependencies. SAAR has not imported its LEAP SDK, Shizuku, Termux, Compose UI or virtual-display backend. Those are not dependencies of the integrated modules above.
