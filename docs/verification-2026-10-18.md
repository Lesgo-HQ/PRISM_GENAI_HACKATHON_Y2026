# Learned workflow reuse verification — 2026-10-18

## Report and baseline

The supplied phone screenshots show a working model connection (`qwen2.5:3b`), saved Zomato and Swiggy workflows, and rejection immediately after teaching the same Swiggy command.

Pulled `b270109` from main before editing. That commit already adds exact saved-command lookup before model routing, independent of the embedding index. Its baseline suite passed 78 tests, with two opt-in live tests skipped. Those changes were preserved.

## Additional fixes

- Recognize polite prefixes such as “Please” and “Can you” while retaining the task, app name, inputs and negation.
- Reject a model-proposed workflow for a different explicitly requested supported app, including Zomato. App names inside search queries do not imply switching apps.
- If the model selects a known workflow with a compatible operation but cannot verify the paraphrase, offer the named saved workflow and resolved inputs for explicit review. Do not send the user into a teaching loop or execute automatically.
- Keep confirmation interactive for valid selections even when model confidence is low. Display the actual resolved inputs, including demonstrated defaults.
- Reject model-produced non-action responses that try to select a skill. Review candidates are constructed by application logic after validation.

Four new regression cases failed against the pulled baseline before the fixes: polite exact matching, uncertain-candidate preservation, cross-app substitution rejection, and interactive candidate confirmation. All passed afterward.

An additional host integration test starts with a saved Zomato workflow, records and saves a Swiggy demonstration, and requests it using exact and polite wording. It reaches confirmation without any model call, without teaching again and without starting actions before approval.

## Results

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 86 passed; two opt-in live tests skipped |
| Live model suite, run separately | Two passed: routing/parameter extraction and action reflection |
| `flutter build apk --debug` | Passed |
| `git diff --check` | Passed |

The live suite used the available cached Qwen3-4B GGUF model through llama.cpp on an isolated local test port. It did not use the friend's Qwen2.5/Ollama instance. The decisive exact-command path is model-independent. These checks do not establish success on a physical Swiggy/Zomato UI or validate fully on-phone inference.

## Phone retest

Update the existing installation from the latest source or APK; do not clear its saved data. With the existing two saved skills, request `order food from swiggy`. Expect either a confirmation naming the saved Swiggy workflow or a focused question for a missing recorded input. Also try `Please order food from swiggy`. Confirm only the intended workflow; payment and credential steps remain manual.

For a paraphrase the model cannot verify, expect a named workflow review and input values, not a claim that the task has already run. Rejecting the review must leave the task inactive. Actual app gestures and completion still require the friend's device retest.
