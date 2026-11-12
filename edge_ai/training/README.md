# WeatherGPT — Edge AI (Phase 3)
## Fine-Tuning & Quantization Guide for Kaggle Dual-T4

This directory contains the self-contained training and quantization pipeline to train **`Qwen/Qwen2.5-0.5B-Instruct`** for offline, on-device weather and Panchangam reasoning on budget Android devices (3–4 GB RAM).

---

### 1. Why Qwen2.5-0.5B-Instruct on Kaggle Dual-T4?
- **Device Safety:** Quantized to INT4 (`Q4_K_M`), the entire model occupies **~352 MB** on disk and **~480–550 MB peak RAM** — safely below Android 10's Low Memory Killer (LMK) kill threshold (< 800 MB).
- **Indic Depth:** Native support for Indian languages (Hindi, Telugu, Tamil, Marathi, Bengali) without tokenizer fragmentation.
- **Kaggle Execution:** Uses free Kaggle GPU quota (Dual T4 or Single T4) and trains in **~15–20 minutes**.

---

### 2. How to Run on Kaggle:

1. Open [Kaggle Notebooks](https://www.kaggle.com/code).
2. Click **New Notebook**.
3. Under **Notebook settings** (right sidebar):
   - **Accelerator:** `GPU T4 x 2` (or `GPU T4 x 1`).
   - **Internet:** `Always on`.
4. Upload or copy [`train_qwen_weather_slm_kaggle.py`](file:///c:/Projects/WeatherGPT/edge_ai/training/train_qwen_weather_slm_kaggle.py) into the notebook cells.
5. Run all cells:
   - Generates 3,500 synthetic grounded ChatML pairs.
   - Runs QLoRA (`r=16`, `lora_alpha=32`, 4-bit NF4 base).
   - Merges LoRA adapter back into FP16 base weights.
   - Automatically clones, builds `llama.cpp`, and quantizes to `Q4_K_M`.
6. Download the final output artifact:
   - `weathergpt-qwen-0.5b-q4_k_m.gguf` (~352 MB).

---

### 3. Deploying to WeatherGPT Android App:

You can test the offline pipeline immediately in the app:
1. Go to **Profile → Settings → OFFLINE EDGE AI (PHASE 3)**.
2. Toggle **Force Offline Edge Mode** to simulate zero-connectivity offline operation.
3. Tap **Qwen2.5-0.5B-Instruct Model** to initialize or download the local GGUF container.
4. Any query in Chat or Voice Assistant will now resolve instantly on-device without internet access, displaying the `⚡ Offline Edge AI` badge!
