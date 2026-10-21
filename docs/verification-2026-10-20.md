# SAAR USB verification — 20–21 October 2026

Tested version 1.0.0 (debug) on the connected Xiaomi 2312DRAABI, Android 15, using local Ollama `qwen3:4b` through USB reverse forwarding. Updated the app in place; did not uninstall it, clear app data, remove saved skills, or delete phone files.

## Confirmed results

| Check | Result |
|---|---|
| Final `flutter test --no-pub` | 103 passed; 3 opt-in live-model tests skipped in this command |
| Final `flutter analyze --no-pub` | No issues |
| Final `flutter build apk --debug --no-pub` | Passed; APK installed with `adb install -r` |
| Cold startup and accessibility | Started; service bound, no crashed accessibility services |
| Local model connection from phone | Structured ready response received through USB |
| Wi-Fi teaching and persistence | Saved exact task name `inspect wifi settings`, one step |
| Wi-Fi replay | All workflow steps verified; screenshot confirms Wi-Fi page, switch remained off |
| Native scroll recording after timing fix | 24 incremental scroll events compiled into one step |
| Native scroll replay | All workflow steps verified |
| Data preservation | Original skill row compared with the pre-update backup and preserved exactly |
| Stop control | Cancelled paused adaptive test successfully |
| Log review | Reviewed app logs, Flutter debugger output, accessibility status, process exit history, build/test logs and Ollama request logs |

## Fixes

- Constrained long home-header status text and made execution/input content scrollable. The installed-app chooser previously caused a 2,819-pixel vertical overflow. Added phone-size and short-viewport regression tests.
- Coalesced consecutive scroll updates, ignored explicit zero-distance updates, and replayed recorded distances within screen bounds. Android now timestamps records using the event occurrence time rather than slow node-read completion time. On this phone, processing delays had split a single swipe into many steps.
- Disabled model thinking for interactive requests, allowed a bounded 120-second local-model response time, constrained confidence to schema enum values, and clarified outcome verification.
- Included child labels for otherwise unnamed clickable rows in model observations. Added a regression test preserving actual target capabilities. Limited action explanation fields and instructed the model to give short responses. Removed redundant geometry and empty/default fields from model prompts while preserving full local fingerprints and target capabilities. The captured Bluetooth verification payload fell from 10,144 to 4,049 characters; it returned the correct result in 36.53 seconds versus 176 seconds in the earlier run (host load differed). The final live success/wrong-page verification test passed in 16 seconds.

## Corrections to the first report

The original report incorrectly blamed teaching-prefix substring offsets. The offsets are correct. ADB keyboard input corrupted the earlier command; exact commands through the debug controller preserved their names. Parser regression tests pass without parser changes.

A historical crash in the device buffer belongs to `com.miui.face`, not SAAR. SAAR exit history includes package updates, our deliberate cold-start force-stop, and Xiaomi `OneKeyClean` kills. These are not evidence of a SAAR exception crash. Xiaomi cleanup can leave accessibility unavailable until re-enabled.

## Model validation and limitations

Earlier live-model tests separately passed action outcome checking, learned-skill routing, and varied intent cases after the fixes. Unsupported or invalid proposals remained rejected. The ordinary host suite does not run these opt-in network tests.

Adaptive Bluetooth navigation is being checked separately on the final build; its final outcome is recorded below. Earlier attempts timed out or proposed an invalid scroll target and were not treated as successful. A captured diagnostic response also generated an excessively long explanation. Model latency was strongly affected by local host load.

The saved `inspect display settings` test still contains a manual boundary because Android supplied an unreadable tap source. The older `pen display settings` skill remains intact. Neither is claimed as a fully automated successful Display workflow. Long flings remain bounded to one screen per replay gesture and may require recovery.

Actual microphone transcription, arbitrary third-party workflows, purchases/messages/deletions, and release-build performance were not exercised. Test commands used the real app controller through the debug VM to avoid unreliable ADB keyboard input. UI navigation and native accessibility gestures ran on the physical phone.

## Evidence

Local evidence is under ignored `build/verification/`: `compact-tests.log`, `compact-analyze.log`, `compact-build.log`, `compact-live-verifier.log`, `final-app.log`, `final-exit-info.log`, `wifi-replayed.png`, database snapshots, and captured local-model requests/responses. These may contain device screen text; they are local and not committed. Log buffers are finite: this is a review of captured test intervals, not every historical phone log.

`uiautomator dump` disrupted SAAR accessibility during earlier tests, so later tests used screenshots and debugger state. Phone screenshots and all added test skills were retained. The Flutter machine-local JDK setting was corrected to the installed Java 25 path so builds could run.

