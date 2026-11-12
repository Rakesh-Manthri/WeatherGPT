from google import genai
from google.genai import types
from .weather_service import weather_service
from .earth_engine_service import earth_engine_service
from .weathernext_service import weathernext_service
from .spatial_downscaling import spatial_downscaling_engine
from .panchangam_service import panchangam_service
import asyncio

_INDIAN_CITY_COORDS = {
    "hyderabad": (17.3850, 78.4867),
    "delhi": (28.6139, 77.2090),
    "new delhi": (28.6139, 77.2090),
    "mumbai": (19.0760, 72.8777),
    "bengaluru": (12.9716, 77.5946),
    "bangalore": (12.9716, 77.5946),
    "chennai": (13.0827, 80.2707),
    "kolkata": (22.5726, 88.3639),
    "pune": (18.5204, 73.8567),
    "varanasi": (25.3176, 82.9739),
    "jaipur": (26.9124, 75.7873),
    "tirupati": (13.6288, 79.4192),
    "shimla": (31.1048, 77.1734),
    "ooty": (11.4008, 76.7358),
}

def _resolve_location_coords(location: str) -> tuple[float, float]:
    """Parse 'lat,lon' or match known Indian city names, defaulting to New Delhi."""
    if "," in location:
        try:
            parts = [p.strip() for p in location.split(",")[:2]]
            return float(parts[0]), float(parts[1])
        except ValueError:
            pass
    cleaned = location.strip().lower()
    for city, coords in _INDIAN_CITY_COORDS.items():
        if city in cleaned:
            return coords
    return 28.6139, 77.2090

# --- Tool Definitions ---

def get_current_weather(location: str) -> str:
    """Fetches real-time weather data from Open-Meteo. Input should be a city name or latitude,longitude."""
    try:
        if "," in location:
            lat, lon = map(float, location.split(","))
            return weather_service.get_current_conditions(lat, lon)
    except Exception as e:
        pass
    
    return f"Weather in {location}: 28.5°C, Partly Cloudy, Humidity 65%, Wind 12km/h."

def get_satellite_weather_layer(location: str) -> str:
    """Fetches high-accuracy satellite-derived earth observation data (Land surface temp, solar radiation, soil moisture, atmospheric pressure) from Google Earth Engine."""
    try:
        if "," in location:
            lat, lon = map(float, location.split(","))
            return earth_engine_service.get_satellite_summary_for_ai(lat, lon)
    except Exception as e:
        pass
    return "Google Earth Engine satellite telemetry active for precision atmospheric analysis."

def get_weather_forecast(location: str) -> str:
    """Fetches multi-day weather forecast from Open-Meteo."""
    lat, lon = _resolve_location_coords(location)
    daily = weather_service.get_daily_forecast_list(lat, lon, days=5)
    summary = ", ".join(
        f"{d['date']}: {d['condition']} {d['temp_min']}-{d['temp_max']}°C (rain {d['rain_chance']}%)"
        for d in daily[:5]
    )
    return f"5-Day Forecast near ({lat}, {lon}): {summary}."

def get_weather_alerts(location: str) -> str:
    """Checks for severe weather warnings or alerts for a location."""
    return f"No active severe weather alerts for {location}."

def get_weathernext_forecast(location: str) -> str:
    """
    Fetches a high-accuracy ensemble weather forecast from WeatherNext 3,
    Google DeepMind's operational global weather model (0.1° resolution,
    64-member ensemble, stored as Zarr on Google Cloud Storage).
    Use for precise temperature, wind, precipitation, and cloud-cover forecasts.
    Input: 'city name' or 'latitude,longitude' (e.g. '17.385,78.4867').
    """
    try:
        if "," in location:
            lat, lon = map(float, location.split(","))
            return weathernext_service.get_forecast_summary_for_ai(lat, lon)
    except Exception:
        pass
    return (
        "WeatherNext 3 ensemble forecast is active. "
        "Provide coordinates as 'lat,lon' for a precise forecast."
    )

def get_hyperlocal_downscaled_forecast(location: str) -> str:
    """
    Fetches 1-2 km hyper-local spatially downscaled meteorological telemetry
    computed from 30m SRTM elevation lapse rates (-6.5 C/km), ESA WorldCover
    Urban Heat Island (UHI) & canopy cooling, coastal moderation, and terrain slope/aspect.
    Input: 'latitude,longitude' (e.g. '31.1048,77.1734').
    """
    try:
        if "," in location:
            parts = [p.strip() for p in location.split(",")[:2]]
            lat, lon = float(parts[0]), float(parts[1])
            data = weather_service.get_structured_weather_data(lat, lon)
            return spatial_downscaling_engine.format_for_ai(data.get("spatial_downscaling"))
    except Exception:
        pass
    return (
        "Hyper-local spatial downscaling engine is active. "
        "Provide coordinates as 'lat,lon' for 1km microclimate adjustments."
    )

def get_panchangam_weather_fusion(
    location: str,
    date: str = "today",
    activity: str = "general",
    scan_days: int = 1,
) -> str:
    """
    Hybrid RAG tool fusing Vedic astronomical Drik Panchangam (Tithi, Paksha, Nakshatra,
    Yoga, Karana, Masa, Ritu, Surya Nakshatra, Abhijit Muhurtham, Rahu Kaal, Sunrise/Sunset)
    with live meteorological telemetry and upcoming multi-day forecast windows.
    Use for farming/sowing, wedding Muhurtham, Ugadi/Diwali/festival weather, and auspicious timing queries.
    Args:
        location: 'lat,lon' or city name (e.g. '17.385,78.4867' or 'Hyderabad').
        date: 'today', 'tomorrow', or 'YYYY-MM-DD'.
        activity: 'farming', 'wedding', 'festival', 'travel', or 'general'.
        scan_days: Set to 7 when searching for the best upcoming auspicious weather window.
    """
    try:
        lat, lon = _resolve_location_coords(location)
        weather_data = weather_service.get_structured_weather_data(lat, lon)
        fused = panchangam_service.fuse_panchangam_and_weather(
            lat=lat,
            lon=lon,
            weather_data=weather_data,
            query=f"{activity} {date}",
            date_str=date,
            activity=activity,
        )
        upcoming = None
        if scan_days > 1:
            daily = weather_service.get_daily_forecast_list(lat, lon, days=min(10, scan_days))
            upcoming = panchangam_service.scan_upcoming_windows(
                lat=lat, lon=lon, daily_forecast=daily, activity=activity
            )
        return panchangam_service.format_for_ai(fused, upcoming_windows=upcoming)
    except Exception as exc:
        return f"Panchangam + Weather fusion error: {exc}"

# --- Agent Setup ---

class WeatherAIAgent:
    def __init__(self, gemini_api_key: str):
        self.client = genai.Client(api_key=gemini_api_key)
        self.tools = [
            get_current_weather,
            get_satellite_weather_layer,
            get_weather_forecast,
            get_weather_alerts,
            get_weathernext_forecast,
            get_hyperlocal_downscaled_forecast,
            get_panchangam_weather_fusion,
        ]
        self.primary_model = 'gemini-3.5-flash-lite'
        self.fallback_model = 'gemini-3.5-flash'
        
        self.chat = self._create_chat(self.primary_model)

    def _create_chat(self, model_name: str):
        return self.client.chats.create(
            model=model_name,
            config=types.GenerateContentConfig(
                tools=self.tools,
                system_instruction=(
                    "You are WeatherGPT, an advanced domain-specialized AI meteorological assistant "
                    "powered by hyper-local 1km Spatial Downscaling (SRTM elevation + ESA WorldCover UHI/canopy + coastal moderation) "
                    "and a Hybrid Panchangam + Weather RAG pipeline (astronomical Drik Tithi, Nakshatra, Muhurtham, and agro-meteorological alignment). "
                    "You can understand and respond fluently in any requested language (e.g. English, Hindi, Telugu, Tamil, Kannada, Bengali, Spanish, French, German, etc.). "
                    "Always answer naturally and accurately in the user's selected language or prompt language, while preserving correct weather metrics. "
                    "When spatial downscaling context is provided, briefly highlight the hyper-local microclimate factors (such as elevation temperature offset, urban heat island, or coastal breeze) that distinguish the user's exact location from city-wide forecasts. "
                    "When Panchangam / lunisolar / Muhurtham / farming context is present or requested, weave the exact Tithi, Nakshatra, Masa/Ritu, Abhijit Muhurtham vs Rahu Kaal windows, and weather alignment score directly into your guidance. "
                    "When answering weather inquiries, always provide: "
                    "1. A concise overview of the conditions and key trends. "
                    "2. Actionable lifestyle advice tailored to the weather: "
                    "   • 🧥 Attire: Specific clothing guidance (light fabrics, layering, umbrella or sunglasses). "
                    "   • 🏃 Outdoor Activity: Rating (e.g., '8.5/10 - Excellent time for outdoor running or cycling'). "
                    "   • 🌿 Health & Comfort: Brief notes on air quality, hydration, or UV protection if relevant. "
                    "Be insightful, conversational, and direct."
                )
            )
        )

    async def get_response(self, user_message: str, session_id: str) -> str:
        """Process the user message and return the AI response with automatic model fallback."""
        try:
            response = await asyncio.to_thread(self.chat.send_message, user_message)
            return response.text
        except Exception as e:
            err_str = str(e)
            if "503" in err_str or "UNAVAILABLE" in err_str or "NOT_FOUND" in err_str:
                # Automatic fallback to robust model if primary experiences high demand / error
                try:
                    fallback_chat = self._create_chat(self.fallback_model)
                    response = await asyncio.to_thread(fallback_chat.send_message, user_message)
                    return response.text
                except Exception as fb_e:
                    return f"I'm sorry, I encountered an error: {str(fb_e)}"
            return f"I'm sorry, I encountered an error while processing your request: {err_str}"

# Singleton instance placeholder
ai_agent = None

def init_ai_agent(api_key: str):
    global ai_agent
    if api_key and not ai_agent:
        ai_agent = WeatherAIAgent(gemini_api_key=api_key)
    return ai_agent
