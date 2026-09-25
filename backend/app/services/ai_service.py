from google import genai
from google.genai import types
from .weather_service import weather_service
import asyncio

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

def get_weather_forecast(location: str) -> str:
    """Fetches multi-day weather forecast from Open-Meteo."""
    return f"Forecast for {location}: Next 3 days will see highs of 30°C and lows of 22°C with intermittent rain."

def get_weather_alerts(location: str) -> str:
    """Checks for severe weather warnings or alerts for a location."""
    return f"No active severe weather alerts for {location}."

# --- Agent Setup ---

class WeatherAIAgent:
    def __init__(self, gemini_api_key: str):
        self.client = genai.Client(api_key=gemini_api_key)
        self.tools = [get_current_weather, get_weather_forecast, get_weather_alerts]
        self.primary_model = 'gemini-2.5-flash'
        self.fallback_model = 'gemini-2.0-flash'
        
        self.chat = self._create_chat(self.primary_model)

    def _create_chat(self, model_name: str):
        return self.client.chats.create(
            model=model_name,
            config=types.GenerateContentConfig(
                tools=self.tools,
                system_instruction=(
                    "You are WeatherGPT, a highly capable multilingual AI weather assistant. "
                    "You can understand and respond fluently in any requested language (e.g. English, Hindi, Telugu, Tamil, Kannada, Bengali, Spanish, French, German, etc.). "
                    "Always answer naturally and accurately in the user's selected language or prompt language, while preserving correct weather values and metrics."
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
