"""
WeatherGPT — Phase 3: Offline Edge AI (Low-VRAM ~3.0 GiB Self-Cleaning Pipeline)
Target Model: Qwen/Qwen2.5-0.5B-Instruct (FP16 LoRA -> Merged -> GGUF Q4_K_M)
Target Hardware: Kaggle T4 (14.56 GiB VRAM)
Output: weathergpt-qwen-0.5b-q4_k_m.gguf (~352 MB)
"""

import gc
import os
import random
import subprocess
import sys
import traceback
from typing import Any, Dict, List

# 1. Lock to GPU 0, prevent CUDA fragmentation, and disable torchvision hooks
os.environ["CUDA_VISIBLE_DEVICES"] = "0"
os.environ["PYTORCH_CUDA_ALLOC_CONF"] = "expandable_segments:True"
os.environ["TOKENIZERS_PARALLELISM"] = "false"
os.environ["TRANSFORMERS_NO_TORCHVISION"] = "1"


# --- Step 0: Reclaim Zombie GPU Memory from Previous Notebook Crashes ---
def free_zombie_vram():
    print("Clearing trapped Jupyter/IPython traceback tensors from GPU 0...")
    if hasattr(sys, "last_traceback") and sys.last_traceback is not None:
        traceback.clear_frames(sys.last_traceback)
        sys.last_traceback = None
    if hasattr(sys, "last_value"):
        sys.last_value = None
    if hasattr(sys, "last_exc"):
        sys.last_exc = None

    try:
        from IPython import get_ipython
        ip = get_ipython()
        if ip is not None:
            for var in ["model", "base_model", "merged_model", "trainer", "batch", "outputs", "loss", "optimizer"]:
                if var in ip.user_ns:
                    del ip.user_ns[var]
    except Exception:
        pass

    gc.collect()
    try:
        import torch
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
            torch.cuda.ipc_collect()
            free_gib, total_gib = [x / (1024**3) for x in torch.cuda.mem_get_info(0)]
            print(f"GPU 0 Ready -> Free: {free_gib:.2f} GiB / Total: {total_gib:.2f} GiB")
    except Exception:
        pass


# --- Step 1: Clean Conflicting Kaggle Packages & Patch In-Memory Imports ---
def install_dependencies():
    print("Removing conflicting Kaggle packages (torchvision, torchaudio, torchao)...")
    subprocess.run(
        [
            sys.executable,
            "-m",
            "pip",
            "uninstall",
            "-y",
            "-q",
            "torchvision",
            "torchaudio",
            "torchao",
        ],
        check=False,
    )
    subprocess.run(
        [
            sys.executable,
            "-m",
            "pip",
            "install",
            "-q",
            "transformers>=4.45.0",
            "peft>=0.13.0",
            "accelerate>=0.34.0",
            "sentencepiece",
            "protobuf",
        ],
        check=True,
    )

    for mod_name in list(sys.modules.keys()):
        if mod_name.startswith(("transformers", "peft", "trl", "accelerate", "torchvision", "torchaudio", "torchao")):
            del sys.modules[mod_name]

    import transformers.utils.import_utils as _t_iu
    _t_iu._torchvision_available = False
    if hasattr(_t_iu, "_torchvision_v2_available"):
        _t_iu._torchvision_v2_available = False
    if hasattr(_t_iu, "_torchaudio_available"):
        _t_iu._torchaudio_available = False

    import peft.import_utils as _p_iu
    _p_iu.is_torchao_available = lambda: False
    try:
        import peft.tuners.lora.torchao as _p_tao
        _p_tao.is_torchao_available = lambda: False
    except Exception:
        pass

    print("Dependencies verified and patched.")


# --- Step 2: Synthesize Diverse Grounded Weather + Panchangam + Disaster Dataset ---
CITIES = [
    ("Hyderabad", 17.3850, 78.4867, "Deccan Plateau semi-arid zone"),
    ("Secunderabad", 17.4399, 78.4983, "Deccan urban ridge"),
    ("Warangal", 17.9689, 79.5941, "Central Telangana agricultural belt"),
    ("Visakhapatnam", 17.6868, 83.2185, "Bay of Bengal cyclone-prone coast"),
    ("Vijayawada", 16.5062, 80.6480, "Krishna river deltaic plain"),
    ("Delhi", 28.6139, 77.2090, "Indo-Gangetic plain with UHI"),
    ("Mumbai", 19.0760, 72.8777, "Konkan coastal marine boundary layer"),
    ("Bengaluru", 12.9716, 77.5946, "Mysore plateau (920m)"),
    ("Chennai", 13.0827, 80.2707, "Coromandel coastal plain"),
    ("Kolkata", 22.5726, 88.3639, "Ganga-Brahmaputra deltaic zone"),
    ("Pune", 18.5204, 73.8567, "Western Ghats leeward rain-shadow"),
    ("Anantapur", 14.6819, 77.6006, "Rayalaseema rain-shadow arid zone"),
]

TITHIS = [
    ("Shukla Pratipada", True),
    ("Shukla Tritiya", True),
    ("Shukla Panchami", True),
    ("Shukla Dashami", True),
    ("Shukla Ekadashi", True),
    ("Purnima", True),
    ("Krishna Tritiya", True),
    ("Krishna Panchami", True),
    ("Krishna Ashtami", False),
    ("Krishna Chaturdashi", False),
    ("Amavasya", False),
]

NAKSHATRAS = [
    ("Rohini", "Sowing & seed treatment"),
    ("Mrigashira", "Transplanting & nursery work"),
    ("Pushya", "Paddy & cotton cultivation"),
    ("Hasta", "Harvesting & grain storage"),
    ("Anuradha", "Soil preparation & irrigation"),
    ("Shravana", "Orchard & horticulture care"),
    ("Ashwini", "Quick-maturing crop sowing"),
    ("Chitra", "Fertilizer & nutrient application"),
]

CONDITIONS = [
    ("Clear Sky", 30.0, 5, 8, 45, 0.0, "NONE"),
    ("Partly Cloudy", 28.5, 20, 12, 58, 1.2, "NONE"),
    ("Overcast", 25.0, 45, 16, 75, 4.5, "WATCH"),
    ("Moderate Rain Showers", 23.0, 80, 24, 88, 18.5, "ADVISORY"),
    ("Severe Thunderstorm & Squall", 21.0, 95, 48, 94, 45.0, "WARNING"),
    ("Cyclonic Depression / Heavy Downpour", 20.0, 98, 72, 96, 115.0, "CRITICAL_ALERT"),
    ("Dense Morning Fog", 17.0, 10, 5, 92, 0.0, "ADVISORY"),
]

SYSTEM_PROMPT = (
    "You are WeatherGPT Edge SLM, an offline-first meteorological and Panchangam AI assistant "
    "running locally on Android. Answer strictly using the provided [Cached Telemetry]. "
    "Never invent metrics not present in the telemetry. Keep responses concise, actionable, "
    "and append the relevant UI action tag at the end."
)


def generate_synthetic_samples(num_samples: int = 4000, seed: int = 42) -> List[Dict[str, Any]]:
    random.seed(seed)
    samples = []

    query_bank = {
        "current_weather": [
            "What's the weather like right now?",
            "Give me the current temperature, humidity, and wind conditions.",
            "How is the weather outside at my location?",
            "Tell me the latest cached weather reading.",
        ],
        "pesticide_spraying": [
            "Can I spray pesticide or neem oil on my cotton crop today?",
            "Is the wind and rain favorable for foliar fertilizer spraying?",
            "Should I apply crop chemicals this afternoon?",
            "Check if weather allows pesticide application right now.",
        ],
        "panchangam_sowing": [
            "Is today auspicious for sowing seeds according to Panchangam and weather?",
            "Give me the Krishi Panchangam and rain check for starting fieldwork.",
            "Match today's Tithi and Nakshatra with soil moisture for planting.",
            "When is the best auspicious window for farming today?",
        ],
        "emergency_protocol": [
            "Network is down and winds are picking up—is there a severe weather alert?",
            "Is it safe to travel or step outside right now? What are the emergency steps?",
            "Give me the offline disaster advisory and flood risk for my area.",
            "We have heavy rain here, what safety protocol should I follow?",
        ],
        "muhurtham_outdoor": [
            "We are planning an outdoor ceremony today. How is the Muhurtham and rain risk?",
            "Check Abhijit Muhurtham and Rahu Kaal alongside today's weather.",
            "Is the weather clear during today's auspicious window?",
        ],
        "ungrounded_refusal": [
            "What will the exact temperature be 14 days from now?",
            "Tell me the live water level of the Nagarjuna Sagar dam right now.",
            "What is the current weather in Tokyo, Japan?",
            "Did the stock market go up today?",
        ],
    }

    intents = list(query_bank.keys())

    for _ in range(num_samples):
        city, lat, lon, terrain = random.choice(CITIES)
        cond, base_t, rain_ch, base_wind, hum, precip_mm, alert_lvl = random.choice(CONDITIONS)
        temp = round(base_t + random.uniform(-2.5, 2.5), 1)
        wind = max(4, base_wind + random.randint(-4, 6))
        soil_moisture = random.randint(22, 85) if rain_ch < 60 else random.randint(65, 95)
        aqi = random.randint(35, 180)
        tithi, is_auspicious_tithi = random.choice(TITHIS)
        nakshatra, nak_activity = random.choice(NAKSHATRAS)
        cache_age_min = random.choice([12, 25, 40, 55, 90])

        intent = random.choice(intents)
        query = random.choice(query_bank[intent])

        telemetry_context = (
            f"Location: {city} ({lat:.4f}N, {lon:.4f}E) | Zone: {terrain} | Cache Age: {cache_age_min}m ago | "
            f"Alert Level: {alert_lvl} | Condition: {cond} | Temp: {temp}°C (High: {round(temp+3.5, 1)}°C, Low: {round(temp-4.0, 1)}°C) | "
            f"Rain Prob: {rain_ch}% ({precip_mm} mm) | Wind: {wind} km/h | Humidity: {hum}% | Soil Moisture: {soil_moisture}% | AQI: {aqi} | "
            f"Panchangam: Tithi={tithi}, Nakshatra={nakshatra} ({nak_activity}), Abhijit=11:48-12:34 IST, Rahu Kaal=13:30-15:00 IST"
        )

        if intent == "current_weather":
            response = (
                f"In {city} (cached {cache_age_min}m ago), conditions show {cond.lower()} at {temp}°C "
                f"(High {round(temp+3.5, 1)}°C / Low {round(temp-4.0, 1)}°C). "
                f"Rain probability is {rain_ch}% ({precip_mm} mm expected), wind speed is {wind} km/h, "
                f"humidity is {hum}%, and AQI stands at {aqi}. <action:weather_card>"
            )
        elif intent == "pesticide_spraying":
            if rain_ch >= 45 or wind >= 18:
                reasons = []
                if rain_ch >= 45:
                    reasons.append(f"high rain probability ({rain_ch}%, {precip_mm} mm) which risks chemical wash-off")
                if wind >= 18:
                    reasons.append(f"elevated wind speeds ({wind} km/h, threshold <15 km/h) which cause spray drift")
                response = (
                    f"Verdict: Delay spraying in {city}. Current telemetry indicates {' and '.join(reasons)}. "
                    f"Wait for calmer conditions below 15 km/h wind and <40% rain probability. <action:agro_advisory>"
                )
            else:
                response = (
                    f"Verdict: Safe to spray in {city}. Rain probability is low ({rain_ch}%) and winds are calm at {wind} km/h "
                    f"(well below the 15 km/h drift threshold). Complete application before Rahu Kaal (13:30-15:00 IST). <action:agro_advisory>"
                )
        elif intent == "panchangam_sowing":
            if is_auspicious_tithi and rain_ch <= 65 and 30 <= soil_moisture <= 80:
                verdict = "Auspicious & Agronomically Favorable"
                advice = (
                    f"{tithi} with {nakshatra} Nakshatra strongly favors {nak_activity.lower()}. "
                    f"Soil moisture is optimal at {soil_moisture}% with manageable rain probability ({rain_ch}%). "
                    f"Best window: before 13:30 IST (prior to Rahu Kaal), ideally during Abhijit Muhurtham (11:48-12:34 IST)."
                )
            else:
                verdict = "Hold / Caution Advised"
                advice = (
                    f"Although today is {tithi} ({nakshatra} Nakshatra), conditions require caution: "
                    f"{'heavy rain risk (' + str(rain_ch) + '%, ' + str(precip_mm) + ' mm) may wash out seeds' if rain_ch > 65 else 'Tithi/soil moisture (' + str(soil_moisture) + '%) is suboptimal for new sowing'}. "
                    f"Avoid initiating major sowing during Rahu Kaal (13:30-15:00 IST)."
                )
            response = f"Verdict for {city}: {verdict}. {advice} <action:panchangam_card>"
        elif intent == "emergency_protocol":
            if alert_lvl in ("WARNING", "CRITICAL_ALERT"):
                response = (
                    f"URGENT [{alert_lvl}]: {city} is experiencing {cond.lower()} with {wind} km/h winds and {precip_mm} mm projected rainfall. "
                    f"1) Avoid low-lying inundation zones and underpasses. "
                    f"2) Stay indoors away from power lines and trees. "
                    f"3) Keep offline cached GIS map open for safe elevation routes. <action:show_cached_map>"
                )
            else:
                response = (
                    f"Status [{alert_lvl}]: No critical disaster warnings in {city} right now. "
                    f"Conditions are {cond.lower()} ({temp}°C, wind {wind} km/h, rain {rain_ch}%). "
                    f"Standard outdoor precautions apply. <action:weather_card>"
                )
        elif intent == "muhurtham_outdoor":
            weather_suitability = (
                "favorable for outdoor gatherings"
                if rain_ch < 40 and wind < 25
                else f"risky outdoors due to {rain_ch}% rain chance and {wind} km/h winds (keep covered backup ready)"
            )
            response = (
                f"Today in {city} features {tithi} and {nakshatra} Nakshatra. "
                f"The prime auspicious window is Abhijit Muhurtham (11:48-12:34 IST), while Rahu Kaal (13:30-15:00 IST) should be avoided. "
                f"At {temp}°C with {cond.lower()}, weather is {weather_suitability}. <action:panchangam_card>"
            )
        else:
            response = (
                f"Offline Cache Limitation: I only have verified telemetry for {city} cached {cache_age_min}m ago "
                f"({cond}, {temp}°C, {rain_ch}% rain). I cannot verify external cities, long-range 14-day forecasts, "
                f"or non-meteorological data without an active connection. <action:offline_notice>"
            )

        samples.append(
            {
                "messages": [
                    {"role": "system", "content": SYSTEM_PROMPT},
                    {"role": "user", "content": f"[Cached Telemetry: {telemetry_context}]\nUser Query: {query}"},
                    {"role": "assistant", "content": response},
                ]
            }
        )

    return samples


# --- Step 3: Low-VRAM PyTorch AMP + Gradient Checkpointing LoRA Fine-Tuning ---
def run_finetuning(output_dir="./weathergpt-qwen-0.5b-lora"):
    import torch
    from peft import LoraConfig, get_peft_model
    from torch.utils.data import DataLoader
    from transformers import AutoModelForCausalLM, AutoTokenizer, get_cosine_schedule_with_warmup

    device = torch.device("cuda:0")
    model_id = "Qwen/Qwen2.5-0.5B-Instruct"
    print(f"Loading base model: {model_id} on {device}...")

    tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    tokenizer.padding_side = "right"

    model = AutoModelForCausalLM.from_pretrained(
        model_id,
        torch_dtype=torch.float16,
        device_map={"": 0},
        trust_remote_code=True,
    )

    # Disable KV cache and enable gradient checkpointing to cut activation VRAM by ~70%
    model.config.use_cache = False
    model.enable_input_require_grads()
    model.gradient_checkpointing_enable()

    lora_config = LoraConfig(
        r=32,
        lora_alpha=64,
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
        lora_dropout=0.05,
        bias="none",
        task_type="CAUSAL_LM",
    )
    model = get_peft_model(model, lora_config)

    # Keep trainable LoRA weights in FP32 for AMP GradScaler stability
    for param in model.parameters():
        if param.requires_grad:
            param.data = param.data.to(torch.float32)

    model.print_trainable_parameters()

    # Attach NEFTune noise hook (alpha=5.0) to input embeddings
    embed_layer = model.get_input_embeddings()

    def neftune_forward_hook(module, args, output):
        if module.training:
            dims = torch.tensor(output.size(1) * output.size(2), dtype=output.dtype, device=output.device)
            mag_norm = 5.0 / torch.sqrt(dims)
            return output + torch.zeros_like(output).uniform_(-mag_norm.item(), mag_norm.item())
        return output

    hook_handle = embed_layer.register_forward_hook(neftune_forward_hook)

    print("Generating and tokenizing synthetic dataset (4,000 samples) with completion-only loss masking...")
    raw_data = generate_synthetic_samples(4000)

    tokenized_rows = []
    for item in raw_data:
        messages = item["messages"]
        prompt_text = tokenizer.apply_chat_template(messages[:-1], tokenize=False, add_generation_prompt=True)
        full_text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=False)

        prompt_ids = tokenizer(prompt_text, add_special_tokens=False)["input_ids"]
        full_ids = tokenizer(full_text, truncation=True, max_length=448, add_special_tokens=False)["input_ids"]

        prompt_len = min(len(prompt_ids), len(full_ids))
        labels = [-100] * prompt_len + full_ids[prompt_len:]

        tokenized_rows.append(
            {
                "input_ids": full_ids,
                "attention_mask": [1] * len(full_ids),
                "labels": labels,
            }
        )

    pad_id = tokenizer.pad_token_id

    def collate_fn(batch: List[Dict[str, List[int]]]) -> Dict[str, torch.Tensor]:
        max_len = max(len(x["input_ids"]) for x in batch)
        max_len = ((max_len + 7) // 8) * 8
        input_ids, attention_mask, labels = [], [], []
        for x in batch:
            pad_len = max_len - len(x["input_ids"])
            input_ids.append(x["input_ids"] + [pad_id] * pad_len)
            attention_mask.append(x["attention_mask"] + [0] * pad_len)
            labels.append(x["labels"] + [-100] * pad_len)
        return {
            "input_ids": torch.tensor(input_ids, dtype=torch.long),
            "attention_mask": torch.tensor(attention_mask, dtype=torch.long),
            "labels": torch.tensor(labels, dtype=torch.long),
        }

    # Micro-batch size = 2 with grad_accum_steps = 8 -> Effective batch size = 16, Peak VRAM ~3.0 GiB
    train_loader = DataLoader(tokenized_rows, batch_size=2, shuffle=True, collate_fn=collate_fn)

    grad_accum_steps = 8
    max_optimizer_steps = 350
    trainable_params = [p for p in model.parameters() if p.requires_grad]

    optimizer = torch.optim.AdamW(trainable_params, lr=2e-4, weight_decay=0.01)
    scheduler = get_cosine_schedule_with_warmup(
        optimizer, num_warmup_steps=25, num_training_steps=max_optimizer_steps
    )
    scaler = torch.amp.GradScaler("cuda")

    print(f"Starting LoRA fine-tuning for {max_optimizer_steps} optimizer steps (Effective Batch Size = 16)...")
    model.train()
    optimizer.zero_grad(set_to_none=True)

    opt_step = 0
    micro_step = 0
    running_loss = 0.0

    while opt_step < max_optimizer_steps:
        for batch in train_loader:
            micro_step += 1
            batch = {k: v.to(device, non_blocking=True) for k, v in batch.items()}

            with torch.amp.autocast("cuda", dtype=torch.float16):
                outputs = model(**batch)
                loss = outputs.loss / grad_accum_steps

            scaler.scale(loss).backward()
            running_loss += loss.item()

            # Free intermediate logit references immediately after backward()
            del outputs, loss, batch

            if micro_step % grad_accum_steps == 0:
                scaler.unscale_(optimizer)
                torch.nn.utils.clip_grad_norm_(trainable_params, max_norm=1.0)
                scaler.step(optimizer)
                scaler.update()
                optimizer.zero_grad(set_to_none=True)
                scheduler.step()
                opt_step += 1

                if opt_step % 25 == 0 or opt_step == 1:
                    avg_loss = running_loss / (25 if opt_step > 1 else 1)
                    lr_now = scheduler.get_last_lr()[0]
                    vram_gib = torch.cuda.max_memory_allocated(0) / (1024**3)
                    print(
                        f"Step [{opt_step:3d}/{max_optimizer_steps}] | Loss: {avg_loss:.4f} | "
                        f"LR: {lr_now:.2e} | Peak VRAM: {vram_gib:.2f} GiB"
                    )
                    running_loss = 0.0

                if opt_step >= max_optimizer_steps:
                    break

    hook_handle.remove()

    print(f"Saving fine-tuned LoRA adapter to {output_dir}...")
    os.makedirs(output_dir, exist_ok=True)
    model.save_pretrained(output_dir)
    tokenizer.save_pretrained(output_dir)

    del model, optimizer, train_loader
    gc.collect()
    torch.cuda.empty_cache()
    return output_dir


# --- Step 4: Merge LoRA, Export to GGUF & Verify ---
def merge_and_quantize(lora_dir="./weathergpt-qwen-0.5b-lora", merged_dir="./weathergpt-0.5b-merged"):
    import torch
    from peft import PeftModel
    from transformers import AutoModelForCausalLM, AutoTokenizer

    model_id = "Qwen/Qwen2.5-0.5B-Instruct"
    print(f"Merging LoRA weights into base model {model_id}...")

    base_model = AutoModelForCausalLM.from_pretrained(
        model_id,
        torch_dtype=torch.float16,
        device_map={"": 0},
        trust_remote_code=True,
    )
    tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)

    model = PeftModel.from_pretrained(base_model, lora_dir)
    merged_model = model.merge_and_unload()
    merged_model.config.use_cache = True
    merged_model.eval()

    # Quick sanity check before GGUF export
    test_messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {
            "role": "user",
            "content": (
                "[Cached Telemetry: Location: Warangal (17.9689N, 79.5941E) | Zone: Central Telangana agricultural belt | "
                "Cache Age: 15m ago | Alert Level: ADVISORY | Condition: Moderate Rain Showers | Temp: 23.5°C (High: 27.0°C, Low: 19.5°C) | "
                "Rain Prob: 80% (18.5 mm) | Wind: 24 km/h | Humidity: 88% | Soil Moisture: 78% | AQI: 52 | "
                "Panchangam: Tithi=Shukla Panchami, Nakshatra=Rohini (Sowing & seed treatment), Abhijit=11:48-12:34 IST, Rahu Kaal=13:30-15:00 IST]\n"
                "User Query: Can I spray pesticide on my cotton crop right now?"
            ),
        },
    ]
    prompt = tokenizer.apply_chat_template(test_messages, tokenize=False, add_generation_prompt=True)
    inputs = tokenizer(prompt, return_tensors="pt").to("cuda:0")
    with torch.no_grad():
        out_ids = merged_model.generate(**inputs, max_new_tokens=120, do_sample=False)
    generated = tokenizer.decode(out_ids[0][inputs["input_ids"].shape[1]:], skip_special_tokens=True)
    print(f"\n--- Merged Model Sanity Check ---\n{generated}\n---------------------------------\n")

    print(f"Saving merged FP16 model to {merged_dir}...")
    merged_model.save_pretrained(merged_dir, safe_serialization=True)
    tokenizer.save_pretrained(merged_dir)

    del inputs, out_ids, merged_model, model, base_model
    gc.collect()
    torch.cuda.empty_cache()

    print("Cloning and compiling llama.cpp (CPU quantizer)...")
    if not os.path.exists("llama.cpp"):
        subprocess.run(["git", "clone", "--depth", "1", "https://github.com/ggml-org/llama.cpp.git"], check=True)
        subprocess.run(["cmake", "-B", "llama.cpp/build", "-S", "llama.cpp", "-DGGML_CUDA=OFF"], check=True)
        subprocess.run(
            ["cmake", "--build", "llama.cpp/build", "--config", "Release", "--target", "llama-quantize", "-j4"],
            check=True,
        )

    subprocess.run([sys.executable, "-m", "pip", "install", "-q", "-e", "llama.cpp/gguf-py"], check=True)

    print("Converting merged HF model to GGUF (FP16)...")
    subprocess.run(
        [
            sys.executable,
            "llama.cpp/convert_hf_to_gguf.py",
            merged_dir,
            "--outfile",
            "weathergpt-0.5b-f16.gguf",
            "--outtype",
            "f16",
        ],
        check=True,
    )

    print("Quantizing to Q4_K_M...")
    quant_binary = "./llama.cpp/build/bin/llama-quantize"
    if not os.path.exists(quant_binary):
        quant_binary = "./llama.cpp/build/llama-quantize"

    output_gguf = "weathergpt-qwen-0.5b-q4_k_m.gguf"
    subprocess.run(
        [quant_binary, "weathergpt-0.5b-f16.gguf", output_gguf, "Q4_K_M"],
        check=True,
    )

    final_size_mb = os.path.getsize(output_gguf) / (1024 * 1024)
    print(f"SUCCESS! Created GGUF model: {output_gguf} ({final_size_mb:.1f} MB)")


if __name__ == "__main__":
    free_zombie_vram()
    install_dependencies()
    lora_path = run_finetuning()
    merge_and_quantize(lora_path)