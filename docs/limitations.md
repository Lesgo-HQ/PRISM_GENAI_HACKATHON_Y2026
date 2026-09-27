# SAAR Limitations

This document details the honest operational limitations of the SAAR system as of the current version.

1. **Regex-based NLU Baseline**: The current Natural Language Understanding (NLU) is based on regex and keyword extraction (`saar-nlu-lite`). It is not a trained neural model, which limits its ability to handle complex paraphrasing or multi-intent commands.
2. **Generalization**: Cross-app generalization is currently an architectural design rather than a physically demonstrated capability. Flows are tightly coupled to the recorded app's UI structure.
3. **ASR Network Dependency**: Automatic Speech Recognition (ASR) relies on Android's native `SpeechRecognizer`, which may require network connectivity depending on the device and OS version.
4. **No Overlay UI**: Currently, there is no floating overlay UI to pause/resume or indicate status during replay.
5. **Trace Quality**: Flow synthesis quality relies heavily on clean action traces during the `RECORDING` phase. Extraneous taps can confuse the Script Engine.
6. **Domain Restriction**: The system's role ontology and intent handling are largely limited to e-commerce and generic navigation patterns.
7. **Single Language**: The system only supports English; there is no multi-language support.
8. **Test Verification**: Tests T1-T14 require physical device verification to ensure the Accessibility Service functions correctly across different manufacturer skins.
