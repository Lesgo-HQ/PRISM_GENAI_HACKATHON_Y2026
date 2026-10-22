# Groq setup

1. Open SAAR → Settings (gear icon).
2. Tap **Use Groq as primary**. This fills `https://api.groq.com/openai/v1/chat/completions`, selects `openai/gpt-oss-20b`, and enables AI.
3. Paste your key into **Groq API key**.
4. Tap **Save & test connection**. Wait for the connected message before running an app task.

The key is stored using encrypted device storage, not in the repository, APK assets, `.env`, or ordinary preferences. The field clears after saving; leaving it blank keeps the saved key. Enter a replacement key to rotate it. It is attached only to requests to the Groq HTTPS endpoint. Do not share the key in chat or screenshots.

Groq receives task messages, relevant screen text, and skill descriptions. Your phone needs internet.

Leave **Use Ollama when Groq is unavailable** enabled. The default fallback endpoint is `http://127.0.0.1:11434/v1/chat/completions` and model is `qwen3:4b`. When Ollama runs on the USB-connected computer, keep its server running and use `adb reverse tcp:11434 tcp:11434`. Groq itself does not need USB forwarding.

Each request tries Groq first. Connection failures, a 30-second timeout, HTTP 408/429, and server errors trigger one Ollama request, with a 120-second local timeout. Missing/rejected keys, invalid request configuration, and malformed model answers do not silently fall back. The Groq key is never sent to Ollama. Settings shows the last successful response source; a successful fallback test does not establish that Groq is healthy.

Groq uses JSON object mode with the requested schema supplied in the prompt; SAAR's existing action parser, capability checks, and verification remain enforced locally. This does not provide provider-enforced strict schema adherence. Local server schema requests are unchanged.

An authentication error means the key needs checking. A rate-limit message means wait or check the Groq account quota. The real-key connection probe was verified on the USB phone on 2026-10-22: Settings displayed "Connected via Groq. Model response verified." Successful connection alone does not prove a complete Zomato workflow.

## Teach and reuse

Tap **Teach a skill** and name the task. Demonstrate it in the target app, then return to SAAR and tap **Stop & Save Skill**. Open **Learned skills**, expand the saved skill to inspect its steps, and tap **Run skill**. You can also say or type its name. Recording stores a reusable procedure on this phone; it does not fine-tune the provider's model weights. Unreadable or sensitive steps require manual help.

An interrupted app-task checkpoint is separate from a learned demonstration. It exists for recovery and must not be described as a newly learned skill.

If saving reports "No target app actions captured", the recording did not contain actions from another app. Naming the skill is only the start: press Android Home, open the target app and demonstrate the steps, then return to SAAR to save. The teaching screen shows the target-app action count. A zero-count recording cannot produce a reusable skill; the explanation is shown in the conversation rather than only in the header.
