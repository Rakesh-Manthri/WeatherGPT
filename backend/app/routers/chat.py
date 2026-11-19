import re
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any
from ..services import ai_service
from ..services.weather_service import weather_service
from ..services.spatial_downscaling import spatial_downscaling_engine
from ..services.panchangam_service import is_panchangam_query, panchangam_service
from ..services.weathernext_service import weathernext_service
from ..services.indic_voice_service import indic_voice_service
from ..middleware.guardrails import LLMGuardrails

router = APIRouter()

class ChatRequest(BaseModel):
    message: str
    lat: float | None = None
    lon: float | None = None
    session_id: str | None = None
    language: str | None = None
    voice_mode: bool = False
    provider: str | None = None

class ChatResponse(BaseModel):
    reply: str
    weather_context_used: bool = False
    weather_data: Optional[Dict[str, Any]] = None
    tts_text: Optional[str] = None
    detected_language: Optional[str] = None
    tts_locale: Optional[str] = None
    stt_locale: Optional[str] = None

def is_weather_query(message: str) -> bool:
    """
    Determines whether a message is seeking meteorological, agricultural,
    panchangam, or outdoor forecast information, as opposed to small talk,
    greetings, or conversational acknowledgments.
    """
    msg = message.strip().lower()
    greetings = {
        "hi", "hello", "hey", "hola", "namaste", "vanakkam", "namaskaram",
        "good morning", "good afternoon", "good evening", "good night",
        "how are you", "how are you?", "who are you", "who are you?",
        "what can you do", "what can you do?", "help", "thanks", "thank you",
        "ok", "okay", "cool", "bye", "goodbye", "test", "testing"
    }
    cleaned = re.sub(r"[^\w\s]", "", msg)
    if cleaned in greetings:
        return False

    weather_keywords = [
        "weather", "forecast", "temp", "temperature", "rain", "rainy", "raining",
        "precipitation", "umbrella", "shower", "downpour", "storm", "cyclone",
        "thunder", "lightning", "wind", "windy", "breeze", "gale", "humidity",
        "humid", "hot", "heat", "cold", "chill", "chilly", "sunny", "sun", "cloud",
        "cloudy", "overcast", "fog", "foggy", "mist", "smog", "aqi", "air quality",
        "pollution", "pressure", "uv", "radar", "satellite", "monsoon",
        "climate", "drizzle", "hail", "snow", "degrees", "celsius",
        "मौसम", "तापमान", "बारिश", "वर्षा", "हवा", "आंधी", "तूफान", "बादल",
        "వాతావరణం", "వర్షం", "ఎండ", "గాలి", "చలి", "ఉష్ణోగ్రత", "తుఫాను",
        "வானிலை", "மழை", "வெயில்", "காற்று",
        "हवामान", "पाऊस", "ऊन", "वारा",
        "panchang", "tithi", "nakshatra", "muhurth", "sow", "crop", "farm", "farming",
        "outdoor", "wear", "jacket", "attire"
    ]

    for kw in weather_keywords:
        if kw in msg:
            return True

    words = msg.split()
    if len(words) <= 3 and not any(kw in msg for kw in weather_keywords):
        return False

    return False

@router.get("/languages")
async def get_supported_voice_languages():
    """Return supported Indic vernacular languages, BCP-47 STT/TTS locales, and sample voice queries."""
    return {"languages": indic_voice_service.get_supported_languages_metadata()}

@router.post("/completions", response_model=ChatResponse)
async def chat_completions(req: ChatRequest):
    # Guardrail: Defend against prompt injection, jailbreaks, and exfiltration
    is_safe, threat_type, refusal_msg = LLMGuardrails.evaluate_prompt(req.message)
    lang_spec = indic_voice_service.resolve_language(req.language, req.message)

    if not is_safe and refusal_msg:
        tts_text = indic_voice_service.sanitize_for_tts(refusal_msg, lang_spec)
        return ChatResponse(
            reply=refusal_msg,
            weather_context_used=False,
            weather_data=None,
            tts_text=tts_text,
            detected_language=lang_spec.english_name,
            tts_locale=lang_spec.tts_locale,
            stt_locale=lang_spec.stt_locale,
        )

    req.message = LLMGuardrails.sanitize_user_input(req.message)

    structured_weather: Optional[Dict[str, Any]] = None
    context_prefix = indic_voice_service.build_prompt_directive(
        lang_spec, voice_mode=req.voice_mode
    ) + " "

    # Fetch structured weather data if coordinates are available
    lat = req.lat
    lon = req.lon
    if lat is not None and lon is not None:
        try:
            structured_weather = weather_service.get_structured_weather_data(lat, lon, provider=req.provider)
            context_prefix += (
                f"[Live Meteorological Telemetry at ({lat}, {lon}): "
                f"Temp={structured_weather['temperature']}°C, Condition={structured_weather['condition']}, "
                f"High={structured_weather['temp_max']}°C, Low={structured_weather['temp_min']}°C, "
                f"Humidity={structured_weather['humidity']}%, Wind={structured_weather['wind_speed']}km/h, "
                f"RainChance={structured_weather['rain_chance']}%, AQI={structured_weather['aqi']}] "
            )
            if structured_weather.get("spatial_downscaling"):
                context_prefix += (
                    f"[{spatial_downscaling_engine.format_for_ai(structured_weather['spatial_downscaling'])}] "
                )
            next_forecast = structured_weather.get("weathernext_forecast") or {}
            if next_forecast.get("status") == "live":
                context_prefix += (
                    "[WeatherNext 3 ensemble forecast: "
                    f"{next_forecast['temperature_2m_c']}°C, "
                    f"dew point {next_forecast['dewpoint_2m_c']}°C, "
                    f"wind {next_forecast['wind_speed_kmh']} km/h, "
                    f"1-hour precipitation {next_forecast['precipitation_1hr_mm']} mm, "
                    f"cloud cover {round(next_forecast['total_cloud_cover_fraction'] * 100)}%, "
                    f"ensemble spread ±{next_forecast['temperature_ensemble_spread_c']}°C.] "
                )
        except Exception as e:
            print(f"Error fetching telemetry: {e}")

    # Hybrid RAG: Attach Panchangam + Weather fusion when cultural/agro/muhurtham intent is detected
    is_panchangam = is_panchangam_query(req.message)
    if is_panchangam:
        try:
            p_lat = lat if lat is not None else 28.6139
            p_lon = lon if lon is not None else 77.2090
            msg_lower = req.message.lower()
            date_match = re.search(r"\b(\d{4}-\d{2}-\d{2})\b", req.message)
            date_hint = (
                date_match.group(1)
                if date_match
                else ("tomorrow" if "tomorrow" in msg_lower else "today")
            )
            fused_panchangam = panchangam_service.fuse_panchangam_and_weather(
                lat=p_lat,
                lon=p_lon,
                weather_data=structured_weather,
                query=req.message,
                date_str=date_hint,
            )
            upcoming_windows = None
            if any(w in msg_lower for w in ("week", "upcoming", "best", "when", "next")):
                daily = weather_service.get_daily_forecast_list(p_lat, p_lon, days=7)
                upcoming_windows = panchangam_service.scan_upcoming_windows(
                    lat=p_lat,
                    lon=p_lon,
                    daily_forecast=daily,
                    activity=fused_panchangam.get("activity_focus", "general"),
                )
                fused_panchangam["upcoming_windows"] = upcoming_windows[:5]

            if structured_weather is None:
                structured_weather = {}
            structured_weather["panchangam_fusion"] = fused_panchangam
            context_prefix += f"[{panchangam_service.format_for_ai(fused_panchangam, upcoming_windows)}] "
        except Exception as e:
            print(f"Error computing Panchangam fusion: {e}")

    has_weather_intent = bool(structured_weather) and (is_weather_query(req.message) or is_panchangam)

    if not ai_service.ai_agent:
        # Fallback if Gemini key is missing
        fallback_reply = "AI agent is not initialized. Please check GEMINI_API_KEY."
        return ChatResponse(
            reply=fallback_reply,
            weather_context_used=has_weather_intent,
            weather_data=structured_weather if has_weather_intent else None,
            tts_text=indic_voice_service.sanitize_for_tts(fallback_reply, lang_spec),
            detected_language=lang_spec.english_name,
            tts_locale=lang_spec.tts_locale,
            stt_locale=lang_spec.stt_locale,
        )

    # Process via Generative AI
    reply = await ai_service.ai_agent.get_response(
        user_message=context_prefix + req.message,
        session_id=req.session_id or "default"
    )
    tts_text = indic_voice_service.sanitize_for_tts(reply, lang_spec)

    return ChatResponse(
        reply=reply,
        weather_context_used=has_weather_intent,
        weather_data=structured_weather if has_weather_intent else None,
        tts_text=tts_text,
        detected_language=lang_spec.english_name,
        tts_locale=lang_spec.tts_locale,
        stt_locale=lang_spec.stt_locale,
    )
