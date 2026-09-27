# SAAR — Samsung PRISM Theme 3
# Full Engineering Audit, Judge Audit & Winning Implementation Plan

> **Repository:** `Lesgo-HQ/SAAR`
>
> **Purpose:** Coding-agent master remediation plan based on the current repository audit, the existing `PLAN.md`, and the Samsung PRISM Theme 3 evaluation criteria.
>
> **Rule:** A feature is not complete merely because a class or UI exists. For PRISM, it must work on a real Android device and have evidence.

---

## 1. Executive Summary

SAAR has a strong architectural foundation, but the current repository is **not yet final hackathon-ready**.

Existing strengths include:

- Flutter application layer
- Kotlin Android `AccessibilityService`
- UI-tree capture
- action recording
- semantic role ontology
- replay engine
- replay-session concepts
- preconditions/postconditions
- recovery logic
- dual-layer credential protection
- STOP control
- local intent-model abstraction
- slot extraction
- flow matching

The major blockers are:

1. Runtime still contains an Anthropic-style `LlmClient` path for intent classification, flow synthesis and embeddings.
2. The current `LocalIntentModel` is regex/keyword logic plus hashed bag-of-words, not a trained NLU model.
3. Clarification/resume integration threatens T10: the replay engine can wait, but the controller does not reliably resume the same step.
4. `ScreenSnapshot` exists, but complete state-aware execution is not finished.
5. Node grounding is still too heuristic for strong cross-app reliability.
6. `ExecutionReport` exists but is not fully wired into persistence/UI.
7. Cross-app generalization is mainly architectural, not physically demonstrated.
8. T1–T14 results must never be marked PASS without actual evidence.
9. Teach traces need stronger sensitive-value redaction.
10. LLM-based flow synthesis should be replaced with a deterministic flow compiler.

The final architecture should have **no runtime LLM API key**.

---

# 2. PRISM Requirements That Must Drive Engineering

Theme 3 requires:

- installable APK
- public source repository
- ≤5-minute unedited demo
- voice + tap teaching
- exact replay
- paraphrase replay
- slot changes
- asking the user when stuck
- architecture documentation
- target-app declaration
- limitations documentation

Automation must use Android Accessibility Service/UI-Automator-style mechanisms.

Do not use:

- hard-coded flows
- app-specific SDKs as substitutes
- deep links as tap substitutes
- web fallback automation
- credential capture
- password/OTP/payment automation

Important evaluation capabilities:

```text
T1 Teach food
T2 Exact replay
T3 Paraphrase
T4 Item slot
T5 Quantity slot
T6 Address slot
T7 Changed screen/popup
T8 Teach ecommerce
T9 Cross-app/slot replay
T10 Genuinely stuck
T11 Credential boundary
T12 Unknown intent
T13 Ambiguity
T14 Reporting
```

Bonus opportunities:

```text
Incidental/unnecessary action filtering
Cross-app semantic generalization
Mid-flow parameter clarification
```

---

# 3. Current Repository Audit

| Area | Status | Priority |
|---|---|---:|
| Flutter/Kotlin architecture | Implemented | P0 |
| AccessibilityService | Implemented | P0 |
| UI tree capture | Implemented | P0 |
| Teach trace | Implemented | P0 |
| Replay engine | Implemented | P0 |
| Replay pause/resume | Partial | P0 |
| Semantic ontology | Implemented | P0 |
| Semantic node ranking | Partial | P0 |
| Preconditions | Partial/implemented | P0 |
| Postconditions | Partial/implemented | P0 |
| Recovery | Partial | P0 |
| Credential guard | Strong foundation | P0 |
| Payment boundary | Partial | P0 |
| STOP | Implemented | P0 |
| Execution report | Partial | P0 |
| Intent abstraction | Implemented | P1 |
| Slot extraction | Prototype | P1 |
| Flow matcher | Prototype | P1 |
| Structured reranking | Incomplete | P1 |
| Ambiguity handling | Partial | P1 |
| Unknown intent | Partial | P1 |
| Semantic embeddings | Prototype | P1 |
| Own ML model | Not complete | P2 |
| Dataset | Not complete | P2 |
| Model evaluation | Not complete | P2 |
| ONNX/mobile inference | Not complete | P2 |
| Quantization | Not complete | P2 |
| Cross-app generalization | Not proven | P3 |
| T1–T14 physical evidence | Not proven | P4 |
| Release APK evidence | Not proven | P4 |
| Final demo evidence | Not proven | P4 |

---

# 4. P0 — Remove Runtime LLM Dependency

## Current problem

`LlmClient` currently provides:

- intent classification
- flow synthesis
- embeddings

and is configured around an Anthropic-style endpoint/API key.

This must not be required by the final application.

## Final architecture

```text
USER SPEECH
    ↓
ASR
    ↓
SAAR-NLU Lite
    ├── intent
    ├── slots
    ├── confidence
    └── embedding
    ↓
Flow Matcher
    ↓
Replay
```

No API key.

No cloud LLM.

No runtime NLU HTTP request.

## Tasks

- Remove `LlmClient` from production execution.
- Remove Anthropic endpoint/model assumptions.
- Remove `LLM_API_KEY` from normal runtime.
- Remove `.env` requirement for normal operation.
- Keep teacher/data-generation tooling under `ml/`.
- If a development cloud fallback remains, disable it by default and never invoke it silently.
- If local inference fails, clarify/stop; never silently execute using weak fallback logic.

## Acceptance

```text
[ ] Fresh install works without API key.
[ ] Airplane mode still performs NLU and flow matching.
[ ] No production NLU HTTP requests.
[ ] No API key committed.
[ ] No API key needed for demo.
```

---

# 5. P0 — Fix T10 Replay Resume

The replay engine contains a waiting/resume concept, but the controller clarification path does not reliably resume the same paused step.

Dangerous current state:

```text
UI: "Continuing..."
ReplayEngine: still waiting
```

## Required behavior

```text
ReplaySession
 currentStep = N
 status = WAITING_FOR_USER
        ↓
user answer
        ↓
ReplaySession.resume(answer)
        ↓
same step N
        ↓
refresh tree
        ↓
re-ground target
        ↓
execute
```

Never restart the whole flow.

## Required model

```dart
class ReplaySession {
  final Flow flow;
  final Map<String, dynamic> slots;
  int currentStep;
  ReplayStatus status;

  Future<void> pause(String reason);
  Future<void> resume(String response);
  void stop();
}
```

## Test

1. Make target unavailable.
2. SAAR asks a clear question.
3. User answers.
4. Same step resumes.
5. Previous steps are not repeated.
6. No random/destructive action occurs.

---

# 6. P0 — Complete State-Aware Replay

Every step must execute through:

```text
CURRENT TREE
    ↓
SCREEN SNAPSHOT
    ↓
SAFETY CHECK
    ↓
PRECONDITION
    ↓
SEMANTIC TARGET RANKING
    ↓
ACTION
    ↓
WAIT FOR UI UPDATE
    ↓
NEW SNAPSHOT
    ↓
POSTCONDITION
    ↓
NEXT STEP
```

A gesture returning `true` is not proof of success.

Implement/complete:

```dart
class ScreenSnapshot {
  final String packageName;
  final Set<String> roles;
  final List<String> visibleTexts;
  final String stateHash;
  final DateTime capturedAt;
}
```

State hash should use normalized semantic/structural information and ignore unstable coordinates/timestamps.

---

# 7. P0 — Preconditions and Postconditions

Each executable step should support:

```json
{
  "id": 4,
  "action": "tap",
  "target_role": "ADD_TO_CART",
  "precondition": {
    "required_roles": ["PRODUCT_DETAIL"],
    "forbidden_roles": ["PASSWORD", "OTP", "PAYMENT"]
  },
  "postcondition": {
    "required_roles": ["CART"]
  },
  "recovery": [
    "dismiss_popup",
    "refind_node",
    "scroll"
  ]
}
```

Before action:

```text
state
→ safety
→ precondition
→ target
```

After action:

```text
action
→ wait
→ new state
→ postcondition
```

If postcondition fails:

```text
recover
→ refresh
→ re-ground
→ verify
```

---

# 8. P0 — Recovery Engine

Required order:

```text
1. Refresh Accessibility tree
2. Re-evaluate current screen
3. Detect safe popup
4. Dismiss safe popup
5. Re-rank target
6. Detect off-screen target
7. Scroll
8. Refresh
9. Re-rank
10. Detect package/screen transition
11. Detect state mismatch
12. Ask user
```

Safe automatic candidates:

```text
OK
Close
Dismiss
Not now
Skip
Later
No thanks
Got it
```

Never auto-click:

```text
Pay
Confirm purchase
Place order
Delete
Transfer
Send money
Remove account
```

---

# 9. P0 — Semantic Node Grounding

Do not use coordinates as primary identity.

Do not rely only on resource IDs.

Implement a dedicated `NodeRanker` combining:

```text
role compatibility
text similarity
content-description similarity
class compatibility
clickability/editability
structural context
screen context
previous-step context
historical consistency
```

Example:

```text
PRODUCT_DETAIL
    ↓
candidate ADD_TO_CART nodes
    ↓
contextual ranking
    ↓
best valid target
```

If confidence is insufficient or candidates are too close:

```text
CLARIFY
```

---

# 10. P0 — Credential/Payment Safety

Keep two independent layers:

```text
Dart policy
+
Kotlin native policy
```

Run the safety check immediately before every action.

Detect at minimum:

```text
PASSWORD
PASSCODE
PIN
OTP
CVV
CVC
CARD NUMBER
EXPIRY
BANK ACCOUNT
IFSC
UPI
PAYMENT
LOGIN
BIOMETRIC CONFIRMATION
PLACE ORDER
PAY
CONFIRM PURCHASE
```

Use:

- input type
- resource ID
- class
- content description
- text/hint
- screen semantics
- package/context
- payment-flow state

### Fail-closed rule

```text
uncertain → BLOCK
```

Never:

```text
uncertain → execute
```

### T11 acceptance

```text
payment/OTP/password/login appears
        ↓
HARD STOP
        ↓
no tap
no typing
no gesture
        ↓
hand control to user
        ↓
report
```

Adversarially test:

- generic payment screens
- custom WebViews
- localized labels
- OTP fields with weak metadata
- biometric confirmation
- generic "Continue" buttons inside payment flows

---

# 11. P0 — Teach Trace Privacy

Raw typed values must not automatically become persistent/model data.

Pipeline:

```text
Raw trace
   ↓
Sensitive Data Redactor
   ↓
Safe trace
   ↓
Flow Compiler
```

Never persist or transmit:

```text
passwords
OTP
card numbers
CVV/CVC
tokens
secrets
```

Use:

```text
<REDACTED>
```

when necessary.

---

# 12. P0 — Replace LLM Flow Synthesis

Final teaching should use a deterministic compiler:

```text
TraceNormalizer
      ↓
RoleMapper
      ↓
StateTransitionAnalyzer
      ↓
SlotAligner
      ↓
FlowCompiler
```

Example:

```text
tap search EditText
    → SEARCH_FIELD

type "margherita"
    → ITEM slot

tap result
    → RESULT_ITEM

tap Add to cart
    → ADD_TO_CART

tap +
    → QUANTITY_INCREASE
```

This is more deterministic, privacy-preserving and easier to defend to judges than an LLM-generated flow.

---

# 13. P0 — Complete Execution Reporting

Wire:

```text
ReplayEngine
    ↓
AppController
    ↓
FlowStore
    ↓
Report UI
```

Report:

```text
run_id
flow_id
status
current_step
total_steps
started_at
ended_at
recoveries
clarifications
stopped_reason
```

Example:

```text
RUN #A91F

Status: STOPPED FOR SAFETY
Flow: Order groceries
Step: 8 / 9
Recoveries: 1
Clarifications: 0
Reason: Payment screen detected

Action required:
Complete payment manually.
```

---

# 14. P1 — Build Real SAAR-NLU

The current `LocalIntentModel` is only a baseline. It is not a trained neural model.

Build:

```text
small Transformer encoder
        │
        ├── Intent classification head
        ├── BIO slot tagging head
        └── Embedding projection head
```

Do not build a general chatbot.

SAAR only needs:

```text
intent
slots
semantic similarity
unknown detection
```

---

# 15. Model Strategy

Benchmark at least:

```text
A: TinyBERT 4-layer
B: MiniLM 6-layer
C: custom 4-layer ~256-hidden student
```

Select based on measured:

```text
intent F1
slot F1
Recall@1
unknown precision/recall
latency
RAM
model size
power
```

Do not select by parameter count alone.

TinyBERT is a useful resource-constrained baseline.

MiniLM is a useful compact semantic baseline.

The final model should be selected using SAAR-specific measurements.

---

# 16. Gemma/Open Model Strategy

Use a model such as Gemma only as an **offline development teacher**, if its current terms are acceptable for the intended dataset/model distribution.

Use:

```text
Teacher
 ↓
paraphrase generation
 ↓
hard-negative generation
 ↓
slot variations
 ↓
dataset validation
 ↓
human review
 ↓
SAAR-NLU student
```

Do not put a multi-billion-parameter generative model into the production phone simply because it is open.

Check the current license/terms before publishing a student model or datasets produced through distillation/synthetic generation.

---

# 17. Dataset

Target approximately:

```text
10k–20k validated utterances
```

as a development target.

Suggested starting distribution:

```text
ORDER_ITEM          1500
SEARCH_ITEM         1500
ADD_TO_CART         1200
CHANGE_QUANTITY     1000
SELECT_ADDRESS       800
CHECKOUT             800
TEACH                800
UNKNOWN             2000
AMBIGUOUS           1000
HARD_NEGATIVE       2000
ASR_VARIANTS        1000
```

Rebalance using validation results.

---

# 18. Intent Taxonomy

Start with:

```text
TEACH
ORDER_ITEM
SEARCH_ITEM
ADD_TO_CART
CHANGE_QUANTITY
SELECT_ADDRESS
CHECKOUT
FILTER
SORT
UNKNOWN
```

Expand only when necessary.

---

# 19. Slot Taxonomy

Use:

```text
ITEM
QUANTITY
ADDRESS
APP
RESTAURANT
CATEGORY
VARIANT
```

Train BIO tags:

```text
B-ITEM
I-ITEM
B-QUANTITY
I-QUANTITY
B-ADDRESS
I-ADDRESS
B-APP
I-APP
...
```

Example:

```text
Order two packets of rice from Zepto

Order       O
two         B-QUANTITY
packets     I-QUANTITY
of          O
rice        B-ITEM
from        O
Zepto       B-APP
```

---

# 20. Hard Negatives

Explicitly distinguish:

```text
SEARCH_ITEM
ORDER_ITEM
ADD_TO_CART
CHANGE_QUANTITY
CHECKOUT
```

Examples:

```text
Search for rice
Order rice
Add rice to cart
Make the rice quantity two
Checkout my rice order
```

These are operationally different despite lexical similarity.

---

# 21. Unknown Intent

Do not implement unknown as "no keyword matched".

Train explicit unknown data:

```text
Book a cab
Play music
Call Mom
Open camera
Set an alarm
Translate this
Send an email
Check weather
Book movie tickets
Reserve a table
```

Also include near-miss commands.

Measure:

```text
unknown precision
unknown recall
false execution rate
```

---

# 22. Ambiguity Dataset

Examples:

```text
Order pizza
Buy something
Get the usual
Order from the app
Add it to cart
```

Expected:

```text
AMBIGUOUS
```

or:

```text
clarification required
```

Never silently guess.

---

# 23. Paraphrase Dataset

Examples:

```text
Order rice
Get me rice
Buy some rice
I want rice
Please order rice
Can you get rice
I'd like to buy rice
```

All should map to the same flow/intent.

Split by template family rather than random rows so the test set measures genuine generalization.

---

# 24. Multi-Task Training

Use a combined objective:

```text
Loss =
  λ1 * IntentLoss
+ λ2 * SlotLoss
+ λ3 * ContrastiveEmbeddingLoss
+ λ4 * DistillationLoss
```

Starting experiment:

```text
λ1 = 0.40
λ2 = 0.30
λ3 = 0.20
λ4 = 0.10
```

Treat these as initial values only. Run ablations.

---

# 25. Embedding Head

Replace hashed bag-of-words with:

```text
Transformer
    ↓
projection
    ↓
128-d vector
    ↓
L2 normalization
```

Train with positive/negative pairs and in-batch negatives.

Positive:

```text
Order rice
Get some rice
```

Negative:

```text
Order rice
Search rice
```

---

# 26. Flow Matcher

Replace free-form LLM reranking with structured scoring:

```text
ParsedIntent
    ↓
candidate flows
    ↓
intent compatibility
+
embedding similarity
+
slot compatibility
+
app compatibility
+
flow completeness
+
top-1/top-2 margin
    ↓
decision
```

Policy:

```text
HIGH
→ execute

MEDIUM
→ confirm/clarify

LOW
→ unknown/clarify
```

Example starting policy:

```text
intent >= 0.85
AND similarity >= calibrated threshold
AND margin >= calibrated margin
AND required slots complete
→ execute
```

Calibrate thresholds on held-out data.

---

# 27. Flow Embeddings

Do not store only one trigger embedding.

Use:

```json
{
  "flow_id": "123",
  "intent": "ORDER_ITEM",
  "prototype_embeddings": [
    "...",
    "...",
    "..."
  ]
}
```

Use several representative utterances.

---

# 28. Cross-App Generalization

Separate:

```text
workflow semantics
```

from:

```text
app implementation
```

Use:

```text
SEARCH_FIELD
RESULT_ITEM
PRODUCT_DETAIL
ADD_TO_CART
CART
CHECKOUT
ADDRESS_SELECTOR
```

not:

```text
AMAZON_SEARCH_BUTTON
ZOMATO_ADD_BUTTON
```

Test the same semantic workflow on similar apps.

---

# 29. Incidental Action Filtering

Package filtering alone is insufficient.

For each recorded action:

```text
action
+
before state
+
after state
```

determine whether it contributes to the intended workflow transition.

If it does not:

```text
candidate incidental action
```

Example:

```text
incoming call
→ answer
→ hang up
```

If the intended workflow state does not depend on it, discard it from the learned flow.

---

# 30. Battery/Memory Rules

The neural model must not run continuously.

Bad:

```text
Accessibility event
→ Transformer
→ Transformer
→ Transformer
```

Good:

```text
user command
→ one NLU inference
→ flow selection
```

During replay use deterministic UI reasoning.

### DO

```text
load model once
reuse inference session
max sequence length ~32 where sufficient
batch size 1
INT8
CPU baseline
cache tokenizer
avoid background inference
```

### DON'T

```text
infer on every AccessibilityEvent
infer once per node
reload model
use generative LLM for role classification
continuously embed screen text
poll the model
```

---

# 31. Mobile Model Deployment

Recommended:

```text
PyTorch
 ↓
ONNX
 ↓
graph optimization
 ↓
INT8 quantization
 ↓
ONNX Runtime / optimized mobile runtime
 ↓
Android
```

Measure:

```text
model size
APK size
cold-start latency
warm latency
P50
P95
RSS/PSS
CPU
battery/power
```

Do not claim numbers until measured.

---

# 32. CPU-First

Start with:

```text
INT8 + CPU
```

Benchmark XNNPACK or other available execution paths where useful.

Do not make the demo dependent on NNAPI/NPU behavior.

---

# 33. Runtime Footprint

Optimize:

- INT8 weights
- short max sequence
- minimal layer count that preserves accuracy
- smaller hidden size if validated
- 128-d retrieval projection
- optimized ONNX graph
- minimal runtime/operator set
- one loaded model session

---

# 34. Recommended Model Variants

Benchmark:

```text
SAAR-NLU-Micro
4 layers
~256 hidden
INT8

SAAR-NLU-Lite
TinyBERT 4-layer
INT8

SAAR-NLU-Plus
MiniLM 6-layer
INT8
```

Only ship multiple variants if measured device adaptation is useful.

---

# 35. Evaluation

## Intent

```text
Accuracy
Macro F1
Per-class F1
```

## Slots

```text
Precision
Recall
F1
Exact span match
```

## Retrieval

```text
Recall@1
Recall@3
MRR
```

## Unknown

```text
Precision
Recall
False execution rate
```

## Safety

```text
Unsafe execution rate
```

The target for defined credential/payment adversarial tests should be:

```text
0 unsafe actions
```

---

# 36. Physical Device Benchmark

Use at least:

```text
1 low-end Android
1 primary test phone
1 stronger phone
```

Measure:

```text
model file size
APK size
cold inference
warm inference
P50
P95
peak RSS/PSS
CPU utilization
battery/power
```

Add measured values to the final documentation.

---

# 37. ASR

Current speech recognition uses Android speech-to-text facilities.

Do not equate:

```text
no LLM API key
```

with:

```text
fully offline
```

unless ASR has also been verified offline.

Document ASR and NLU separately.

---

# 38. T1–T14 Physical Test Protocol

Never mark PASS merely because code exists.

Every test must include:

```text
Setup
Command
Expected
Observed
Result
Evidence
Failure reason
Fix
```

## T1

Teach a food workflow from scratch.

## T2

Replay exact command and stop at payment.

## T3

Two paraphrases must map to the learned flow.

## T4

Change item.

## T5

Change quantity.

## T6

Change address.

## T7

Introduce popup/screen change and recover.

## T8

Teach a second ecommerce workflow.

## T9

Test semantic transfer and slot replay.

## T10

Make target genuinely unavailable. SAAR must ask/report instead of guessing. Then verify clarification resumes the same step.

## T11

Reach credential/payment screen. Zero automated interaction beyond boundary.

## T12

Unknown command must not execute an existing flow.

## T13

Ambiguous command must clarify.

## T14

Show accurate run report.

---

# 40. Judge-Facing Differentiators

Emphasize:

1. One-shot workflow learning.
2. Semantic rather than coordinate replay.
3. On-device NLU with no LLM API key.
4. Parameterized workflows.
5. State-aware replay.
6. Recovery from benign changes.
7. User clarification instead of guessing.
8. Fail-closed credential/payment boundary.
9. Small INT8 model for low-end Android.
10. Cross-app semantic workflows.

---

# 41. Anti-Patterns

Never:

```text
blind coordinate replay
cloud LLM as required runtime
LLM directly controlling AccessibilityService
execution at low confidence
silent ambiguity resolution
password/OTP entry
payment automation
sensitive-value logging
unmeasured benchmark claims
PASS without test evidence
model confidence overriding safety
```

---

# 42. Target Repository Structure

```text
SAAR/
├── lib/
│   ├── models/
│   │   ├── parsed_intent.dart
│   │   ├── execution_report.dart
│   │   ├── replay_session.dart
│   │   ├── screen_snapshot.dart
│   │   └── ...
│   ├── services/
│   │   ├── saar_nlu.dart
│   │   ├── slot_decoder.dart
│   │   ├── flow_matcher.dart
│   │   ├── flow_compiler.dart
│   │   ├── trace_normalizer.dart
│   │   ├── screen_analyzer.dart
│   │   ├── node_ranker.dart
│   │   ├── recovery_engine.dart
│   │   ├── credential_guard.dart
│   │   └── replay_engine.dart
│   └── screens/
│
├── android/
│   └── app/src/main/kotlin/com/lesgo/saar/
│       ├── MainActivity.kt
│       ├── SaarAccessibilityService.kt
│       └── LocalNluEngine.kt
│
├── ml/
│   ├── data/
│   │   ├── train.jsonl
│   │   ├── dev.jsonl
│   │   └── test.jsonl
│   ├── generate_dataset.py
│   ├── validate_dataset.py
│   ├── train.py
│   ├── evaluate.py
│   ├── export_onnx.py
│   ├── quantize.py
│   └── README.md
│
├── assets/
│   └── models/
│       ├── saar_nlu_int8.onnx
│       ├── tokenizer.json
│       └── model_metadata.json
│
├── docs/
│   ├── architecture.md
│   ├── safety.md
│   ├── limitations.md
│   └── prism-test-matrix.md
│
└── test/
```

---

# 43. Implementation Priority

## P0 — Reliability/Safety

1. Remove runtime LLM dependency.
2. Make fresh install work without API key.
3. Fix ReplaySession clarification/resume.
4. Complete ScreenSnapshot gating.
5. Complete pre/postconditions.
6. Complete RecoveryEngine.
7. Improve semantic grounding.
8. Harden credential/payment boundary.
9. Add trace redaction.
10. Complete STOP.
11. Complete ExecutionReport.
12. Fix native bridge argument mismatch.
13. Add integration tests.

## P1 — Intelligence

14. `ParsedIntent`.
15. Model-compatible slot decoder.
16. FlowMatcher redesign.
17. Structured confidence.
18. Ambiguity.
19. Unknown intent.
20. Semantic flow prototypes.

## P2 — Own Model

21. Dataset schema.
22. Dataset generation.
23. Dataset validation.
24. Hard negatives.
25. Unknown/ambiguity sets.
26. ASR-noise set.
27. Train baseline.
28. Intent head.
29. BIO slot head.
30. Embedding head.
31. Evaluate.
32. Distill if useful.
33. ONNX export.
34. INT8.
35. Android integration.
36. RAM/latency/power measurement.

## P3 — Differentiation

37. Cross-app transfer.
38. Incidental-action filtering.
39. Mid-flow clarification.
40. Stronger state reasoning.
41. Adaptive recovery.
42. Rich reporting.

## P4 — Submission

43. Physical T1–T14.
44. Fix all failures.
45. Release APK.
46. Clean-install verification.
47. No-API-key verification.
48. Architecture docs.
49. Safety docs.
50. Limitations.
51. ≤5-minute demo.
52. Repository cleanup.
53. Final regression.

---

# 44. Coding-Agent Operating Procedure

For every phase:

1. Inspect existing code.
2. Identify affected files.
3. Make the smallest coherent change.
4. Run:

```bash
dart format .
flutter analyze
flutter test
```

5. If Android code changed:

```bash
flutter build apk --debug
```

6. Test on a physical device.
7. Record observed behavior.
8. Update the PRISM matrix.
9. Only then move forward.

Do not perform a giant rewrite that destroys working behavior.

---

# 45. Definition of Done

```text
[ ] no runtime API key
[ ] no production NLU HTTP calls
[ ] AccessibilityService works
[ ] teach works
[ ] semantic flow compiler works
[ ] flow persistence works
[ ] exact replay works
[ ] paraphrase works
[ ] item slot works
[ ] quantity slot works
[ ] address slot works
[ ] popup recovery works
[ ] scroll recovery works
[ ] changed-screen detection works
[ ] ReplaySession pauses correctly
[ ] clarification resumes SAME step
[ ] unknown intent does not execute
[ ] ambiguity causes clarification
[ ] credential guard fail-closed
[ ] OTP guard fail-closed
[ ] payment boundary fail-closed
[ ] STOP works
[ ] ExecutionReport works
[ ] sensitive data redacted
[ ] SAAR-NLU model exists
[ ] SAAR-NLU evaluated
[ ] SAAR-NLU runs locally
[ ] Android model integration works
[ ] model size measured
[ ] RAM measured
[ ] latency measured
[ ] power measured
[ ] cross-app tested
[ ] incidental actions tested
[ ] T1 evidence
[ ] T2 evidence
[ ] T3 evidence
[ ] T4 evidence
[ ] T5 evidence
[ ] T6 evidence
[ ] T7 evidence
[ ] T8 evidence
[ ] T9 evidence
[ ] T10 evidence
[ ] T11 evidence
[ ] T12 evidence
[ ] T13 evidence
[ ] T14 evidence
[ ] release APK
[ ] clean install
[ ] final demo
[ ] README matches implementation
[ ] limitations documented
[ ] repository cleaned
```

---

# 46. Final Product Definition

```text
USER
"Order two packets of rice."

        ↓

ASR

        ↓

SAAR-NLU
intent = ORDER_ITEM
item = rice
quantity = 2
confidence = high

        ↓

FLOW MATCHER

        ↓

REPLAY SESSION

        ↓

ACCESSIBILITY TREE

        ↓

SEMANTIC GROUNDER
SEARCH_FIELD

        ↓

SAFETY

        ↓

EXECUTE

        ↓

VERIFY
RESULT_LIST

        ↓

EXECUTE
type rice

        ↓

VERIFY
RESULT_ITEM

        ↓

EXECUTE
select semantic result

        ↓

RECOVERY if popup

        ↓

QUANTITY = 2

        ↓

ADDRESS

        ↓

CHECKOUT

        ↓

PAYMENT SCREEN

        ↓

CREDENTIAL GUARD
BLOCK

        ↓

HAND CONTROL TO USER

        ↓

EXECUTION REPORT
"Automation stopped before payment for safety."
```

---

# 47. Winning Technical Thesis

Do not present SAAR merely as an "AI that clicks apps."

Present it as:

> **A lightweight, on-device, teach-once Android automation system that learns semantic workflows from demonstrations, generalizes natural-language commands and parameters, grounds actions against the live Accessibility UI tree, recovers from benign UI changes, asks the user when uncertain, and deterministically stops before credentials and payment.**

The strongest technical stack is:

```text
ON-DEVICE NLU
        +
SEMANTIC WORKFLOW LEARNING
        +
ACCESSIBILITY GROUNDING
        +
STATE-AWARE REPLAY
        +
RECOVERY
        +
CLARIFICATION
        +
FAIL-CLOSED SAFETY
        +
LOW RESOURCE FOOTPRINT
```

---

# 48. Final Coding-Agent Directive

Treat this document as the master remediation plan.

Before changing code:

1. Inspect current implementation.
2. Preserve working functionality.
3. Implement P0 first.
4. Implement P1 next.
5. Build the real local model only after the runtime interfaces are stable.
6. Do not claim a model exists until a trained artifact exists.
7. Do not claim local inference until Android runs it.
8. Do not claim fully offline unless ASR is also verified offline.
9. Do not mark T1–T14 PASS without physical evidence.
10. Do not introduce an API-key dependency.
11. Never weaken credential/payment safety for task completion.
12. Never allow model confidence to override deterministic safety.
13. Run format/analyze/test/build after changes.
14. Keep commits small.
15. Update documentation to match actual behavior.

## Final objective

```text
LEARN
  ↓
UNDERSTAND
  ↓
GENERALIZE
  ↓
GROUND
  ↓
EXECUTE
  ↓
VERIFY
  ↓
RECOVER
  ↓
ASK
  ↓
STOP SAFELY
  ↓
REPORT
```

with **no runtime LLM API key** and a **small, measured, on-device SAAR-NLU model suitable for low-end Android devices**.
