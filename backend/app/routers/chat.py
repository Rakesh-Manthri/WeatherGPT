from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Dict, Any
from ..services import ai_service
from ..services.weather_service import weather_service

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
        except Exception as e:
            print(f"Error fetching telemetry: {e}")

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
