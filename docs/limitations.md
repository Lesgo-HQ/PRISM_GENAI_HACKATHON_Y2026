# Current limitations

- Exact saved commands are deterministic; general paraphrases and adaptive planning depend on model quality. A connection test establishes protocol connectivity, not routing accuracy.
- The keyword/hash fallback is limited. ONNX assets and a native inference bridge exist, but LocalIntentModel.parse does not use a validated neural intent/slot/embedding pipeline. No measured on-device model quality or resource claim is made.
- Learned workflows are app-specific. Cross-app transfer has not been demonstrated. An app with unavailable or unlabeled accessibility nodes can require manual steps even after teaching.
- Older recordings containing stop_before steps retain those boundaries. Missing historical targets cannot safely be reconstructed; inspect the skill and demonstrate it again if the captured procedure is inadequate.
- Quantity/address extraction supports basic forms; substitution only affects declared workflow slots. A demonstrated tap on a quantity increment is not automatically a reusable quantity loop.
- Recovery is bounded and heuristic. Screen changes alone are weak evidence for steps without explicit postconditions. Arbitrary UI redesigns, popups, multiple identical controls and canvas interfaces can prevent replay.
- Floating recording/replay controls exist. Microphone recognition, OEM background limits and accessibility-service restarts still need wider device testing. A process kill can lose an in-progress native recording; committed workflows survive app restart.
- Credentials and payment remain manual. Metadata and label checks cannot prove detection of every custom/localized financial UI.
- The installed Android speech recognizer may use a network. Fully offline speech operation has not been established.
- Full T1–T14 cross-app physical evidence, multi-device benchmarks, release signing and the unedited submission video remain outstanding. See the [requirements audit](requirements-audit-2026-10-18.md).
