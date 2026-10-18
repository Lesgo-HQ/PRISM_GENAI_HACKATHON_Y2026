# Experimental SAAR-NLU models

ONNX model/data files are present here and in Android assets. Kotlin exposes an ONNX inference bridge. Production LocalIntentModel.parse currently uses keyword rules, and embed uses hashed token counts; it does not consume the ONNX output.

These files are not evidence of a validated production NLU model. Training provenance, held-out intent/slot/retrieval metrics, tokenizer compatibility, quantization and Android resource measurements are required before claiming the on-device neural requirements are complete.
