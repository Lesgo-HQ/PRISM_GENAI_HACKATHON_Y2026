# PRISM Test Matrix T1-T14

| ID | Scenario | Setup | Command | Expected | Observed | Status |
|---|---|---|---|---|---|---|
| T1 | Teach food workflow | App in home screen | "Watch me order food" | trace -> filtered -> synthesized flow saved | | IMPLEMENTED - needs device verification |
| T2 | Exact replay | App in home screen | "Order food exactly like before" | correct flow selected, deterministic grounding | | IMPLEMENTED - needs device verification |
| T3 | Paraphrase | App in home screen | "Grab me some grub" | same flow via embedding+intent model | | IMPLEMENTED - needs device verification |
| T4 | Item slot | App in home screen | "Order a burger" | SlotExtractor replaces item in flow | | IMPLEMENTED - needs device verification |
| T5 | Quantity slot | App in home screen | "Order two coffees" | word->int normalize 2 | | IMPLEMENTED - needs device verification |
| T6 | Address slot | App in home screen | "Send it to work" | addressSelector resolved to work address | | IMPLEMENTED - needs device verification |
| T7 | Popup recovery | App in home screen, mock popup | "Order pizza" | RecoveryEngine dismiss safe popup, resume flow | | IMPLEMENTED - needs device verification |
| T8 | Teach ecommerce | App in home screen | "Watch me buy a shirt" | second flow saved independently | | IMPLEMENTED - needs device verification |
| T9 | Cross-app | Two different apps | "Buy item X" | ontology app-independent, generalizes | | IMPLEMENTED - needs device verification |
| T10 | Stuck -> clarify -> resume | Flow interrupted | "Order pizza" | ReplaySession pause/resume at same step | | IMPLEMENTED - needs device verification |
| T11 | Credential boundary | Try to read password | "Show password" | dual fail-closed guard blocks execution | | IMPLEMENTED - needs device verification |
| T12 | Unknown intent | App in home screen | "Do a barrel roll" | returns UNKNOWN, asks user to teach | | IMPLEMENTED - needs device verification |
| T13 | Ambiguity | Multiple similar flows | "Order food" | margin <0.07 -> clarify prompt shown | | IMPLEMENTED - needs device verification |
| T14 | Reporting | After a run | N/A | ExecutionReport generated with recoveries/clarifications | | IMPLEMENTED - needs device verification |
