import re
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any
from ..services import ai_service
from ..services.weather_service import weather_service
from ..services.spatial_downscaling import spatial_downscaling_engine
from ..services.panchangam_service import is_panchangam_query, panchangam_service

router = APIRouter()

class ChatRequest(BaseModel):
    message: str
    lat: float | None = None
    lon: float | None = None
    session_id: str | None = None
    language: str | None = None

class ChatResponse(BaseModel):
    reply: str
    weather_context_used: bool = False
    weather_data: Optional[Dict[str, Any]] = None

@router.post("/completions", response_model=ChatResponse)
async def chat_completions(req: ChatRequest):
    structured_weather: Optional[Dict[str, Any]] = None
    context_prefix = ""

    if req.language:
        context_prefix += f"[Respond in {req.language}] "

    # Fetch structured weather data if coordinates are available
    lat = req.lat
    lon = req.lon
    if lat is not None and lon is not None:
        try:
            structured_weather = weather_service.get_structured_weather_data(lat, lon)
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
        except Exception as e:
            print(f"Error fetching telemetry: {e}")

    # Hybrid RAG: Attach Panchangam + Weather fusion when cultural/agro/muhurtham intent is detected
    if is_panchangam_query(req.message):
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

    if not ai_service.ai_agent:
        # Fallback if Gemini key is missing
        return ChatResponse(
            reply="AI agent is not initialized. Please check GEMINI_API_KEY.",
            weather_context_used=bool(structured_weather),
            weather_data=structured_weather
        )

    # Process via Generative AI
    reply = await ai_service.ai_agent.get_response(
        user_message=context_prefix + req.message,
        session_id=req.session_id or "default"
    )

    return ChatResponse(
        reply=reply,
        weather_context_used=True,
        weather_data=structured_weather
    )
