# WeatherGPT Edge SLM — Model Storage

This directory holds the quantized GGUF weights for on-device, zero-latency, offline Edge AI inference in WeatherGPT.

## Model Specifications

- **Target Architecture:** Qwen2.5 (490M Parameters)
- **Base Model:** `Qwen/Qwen2.5-0.5B-Instruct`
- **Training Paradigm:** Domain LoRA fine-tuning on meteorological telemetry, Indic Krishi Panchangam, and disaster protocols (trained on Kaggle Dual-T4).
- **Quantization:** GGUF v3 `Q4_K_M` via `llama.cpp`
- **File Name:** `weathergpt-qwen-0.5b-q4_k_m.gguf`
- **File Size:** ~379.4 MB (397,807,680 bytes)
- **Metadata Verified:**
  - Architecture: `qwen2`
  - Tensors: `290`
  - Context Length: `32768` (Active on Android: capped to 512 tokens to conserve RAM)
  - Embedding Length: `896`
  - Feed-Forward Length: `4864`
  - Attention Heads: `14`

## Android Memory Safety
Configured with `android:largeHeap="true"` in `android/app/src/main/AndroidManifest.xml` to prevent Linux OOM-killer (LMK) eviction on 3–4 GB RAM devices.
