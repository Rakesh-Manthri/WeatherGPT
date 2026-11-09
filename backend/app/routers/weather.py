from fastapi import APIRouter
from ..services.weather_service import weather_service

router = APIRouter()

@router.get("/current")
async def get_current_weather(lat: float, lon: float):
    data = weather_service.get_structured_weather_data(lat, lon)
    return {
        "location": {"lat": lat, "lon": lon},
        "temperature_c": data["temperature"],
        "apparent_temperature_c": data["apparent_temperature"],
        "condition": data["condition"],
        "humidity": data["humidity"],
        "wind_kph": data["wind_speed"],
        "rain_chance": data["rain_chance"],
        "aqi": data["aqi"],
    }

@router.get("/forecast")
async def get_forecast(lat: float, lon: float, days: int = 7):
    data = weather_service.get_structured_weather_data(lat, lon)
    return {
        "location": {"lat": lat, "lon": lon},
        "current": data,
        "hourly": data["hourly"],
        "forecast": [
            {"day": "Today", "max_temp": data["temp_max"], "min_temp": data["temp_min"], "condition": data["condition"]},
        ]
    }
