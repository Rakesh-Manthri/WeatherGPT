"""
WeatherGPT — Phase 3: Offline Edge AI (Enhanced Production Pipeline)
Target Model: Qwen/Qwen2.5-0.5B-Instruct (FP16 LoRA -> Merged -> GGUF Q4_K_M)
Target Hardware: Kaggle T4 (Single or Dual T4 safe)
Output: weathergpt-qwen-0.5b-q4_k_m.gguf (~352 MB)
"""

import gc
import inspect
import json
import os
import random
import subprocess
import sys
from typing import Any, Dict, List

# Force single-GPU visibility to prevent Kaggle Dual-T4 DataParallel crashes
os.environ["CUDA_VISIBLE_DEVICES"] = "0"
os.environ["TOKENIZERS_PARALLELISM"] = "false"


# --- Step 1: Install Dependencies ---
def install_dependencies():
    print("Installing training & GGUF conversion dependencies...")
    subprocess.run(
        [
            sys.executable,
            "-m",
            "pip",
            "install",
            "-q",
            "-U",
            "torch",
            "transformers>=4.45.0",
            "peft>=0.13.0",
            "trl>=0.11.0",
            "accelerate>=0.34.0",
            "datasets>=2.20.0",
            "sentencepiece",
            "protobuf",
        ],
        check=True,
    )


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
                reason_str = " and ".join(reasons)
                response = (
                    f"Verdict: Delay spraying in {city}. Current telemetry indicates {reason_str}. "
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

        else:  # ungrounded_refusal
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


# --- Step 3: Run FP16 LoRA Fine-Tuning with Completion-Only Loss Masking ---
def run_finetuning(output_dir="./weathergpt-qwen-0.5b-lora"):
    import torch
    from datasets import Dataset
    from peft import LoraConfig, get_peft_model
    from transformers import AutoModelForCausalLM, AutoTokenizer
    from trl import DataCollatorForCompletionOnlyLM, SFTConfig, SFTTrainer

    model_id = "Qwen/Qwen2.5-0.5B-Instruct"
    print(f"Loading base model: {model_id} in pure FP16 on cuda:0...")

    tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=True)
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    tokenizer.padding_side = "right"

    # Pure FP16 on GPU 0 (~1 GB VRAM) avoids Dual-T4 crashes and 4-bit quantization noise
    model = AutoModelForCausalLM.from_pretrained(
        model_id,
        torch_dtype=torch.float16,
        device_map={"": 0},
        trust_remote_code=True,
    )

    lora_config = LoraConfig(
        r=32,
        lora_alpha=64,
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
        lora_dropout=0.05,
        bias="none",
        task_type="CAUSAL_LM",
    )
    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()

    print("Generating synthetic grounded dataset (4,000 samples)...")
    raw_data = generate_synthetic_samples(4000)

    # Pre-render ChatML strings so DataCollatorForCompletionOnlyLM works across all TRL versions
    formatted_rows = [
        {"text": tokenizer.apply_chat_template(item["messages"], tokenize=False, add_generation_prompt=False)}
        for item in raw_data
    ]
    full_dataset = Dataset.from_list(formatted_rows).train_test_split(test_size=0.05, seed=42)

    # Mask loss on System and User turns; train 100% on Assistant responses
    response_template = "<|im_start|>assistant\n"
    data_collator = DataCollatorForCompletionOnlyLM(
        response_template=response_template,
        tokenizer=tokenizer,
    )

    # Handle TRL version differences between max_seq_length and max_length cleanly
    sft_sig = inspect.signature(SFTConfig.__init__).parameters
    seq_len_kwarg = {"max_length": 512} if "max_length" in sft_sig else {"max_seq_length": 512}
    text_field_kwarg = {"dataset_text_field": "text"} if "dataset_text_field" in sft_sig else {}

    sft_args = SFTConfig(
        output_dir=output_dir,
        per_device_train_batch_size=8,
        per_device_eval_batch_size=8,
        gradient_accumulation_steps=2,
        num_train_epochs=1.5,
        warmup_ratio=0.06,
        learning_rate=2e-4,
        lr_scheduler_type="cosine",
        weight_decay=0.01,
        fp16=True,
        logging_steps=25,
        eval_strategy="steps" if "eval_strategy" in sft_sig else "no",
        eval_steps=100,
        save_strategy="no",
        neftune_noise_alpha=5.0,
        report_to="none",
        seed=42,
        **seq_len_kwarg,
        **text_field_kwarg,
    )

    trainer_kwargs = {
        "model": model,
        "train_dataset": full_dataset["train"],
        "eval_dataset": full_dataset["test"],
        "data_collator": data_collator,
        "args": sft_args,
    }
    if "processing_class" in inspect.signature(SFTTrainer.__init__).parameters:
        trainer_kwargs["processing_class"] = tokenizer
    else:
        trainer_kwargs["tokenizer"] = tokenizer

    trainer = SFTTrainer(**trainer_kwargs)

    print("Starting FP16 LoRA fine-tuning...")
    trainer.train()

    print(f"Saving fine-tuned LoRA adapter to {output_dir}...")
    model.save_pretrained(output_dir)
    tokenizer.save_pretrained(output_dir)

    # Free GPU memory before merging
    del trainer, model
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
        out_ids = merged_model.generate(**inputs, max_new_tokens=120, temperature=0.1, do_sample=False)
    generated = tokenizer.decode(out_ids[0][inputs["input_ids"].shape[1]:], skip_special_tokens=True)
    print(f"\n--- Merged Model Sanity Check ---\n{generated}\n---------------------------------\n")

    print(f"Saving merged FP16 model to {merged_dir}...")
    merged_model.save_pretrained(merged_dir, safe_serialization=True)
    tokenizer.save_pretrained(merged_dir)

    del merged_model, model, base_model
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

    # Install matching gguf-py from the cloned llama.cpp repo to prevent version conflicts
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
    output_gguf = "weathergpt-qwen-0.5b-q4_k_m.gguf"
    subprocess.run(
        [quant_binary, "weathergpt-0.5b-f16.gguf", output_gguf, "Q4_K_M"],
        check=True,
    )

    final_size_mb = os.path.getsize(output_gguf) / (1024 * 1024)
    print(f"SUCCESS! Created GGUF model: {output_gguf} ({final_size_mb:.1f} MB)")


if __name__ == "__main__":
    install_dependencies()
    lora_path = run_finetuning()
    merge_and_quantize(lora_path)
