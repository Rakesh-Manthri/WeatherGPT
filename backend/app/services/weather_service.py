import httpx
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

class WeatherService:
    def __init__(self):
        self.base_url = "https://api.open-meteo.com/v1/forecast"

    def get_current_conditions(self, lat: float, lon: float) -> str:
        """Fetch current conditions using Open-Meteo API."""
        try:
            params = {
                "latitude": lat,
                "longitude": lon,
                "current": ["temperature_2m", "relative_humidity_2m", "apparent_temperature", "is_day", "precipitation", "rain", "showers", "snowfall", "weather_code", "cloud_cover", "pressure_msl", "surface_pressure", "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m"],
                "timezone": "auto"
            }
            
            with httpx.Client() as client:
                response = client.get(self.base_url, params=params)
                response.raise_for_status()
                data = response.json()
                
                current = data.get("current", {})
                temp_c = current.get("temperature_2m", "N/A")
                humidity = current.get("relative_humidity_2m", "N/A")
                wind_speed = current.get("wind_speed_10m", "N/A")
                
                # Simple weather code mapping (WMO codes)
                code = current.get("weather_code", 0)
                condition = "Clear" if code == 0 else "Cloudy" if code in [1,2,3] else "Rain/Snow"
                
                return f"Weather (Open-Meteo): {temp_c}°C, {condition}, Humidity {humidity}%, Wind {wind_speed}km/h."
                
        except Exception as e:
            logger.error(f"Open-Meteo Error: {e}")
            return "Failed to retrieve real-time data from Open-Meteo."

weather_service = WeatherService()
