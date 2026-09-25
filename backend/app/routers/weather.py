from fastapi import APIRouter, Depends, HTTPException
from typing import Optional

router = APIRouter()

@router.get("/current")
async def get_current_weather(lat: float, lon: float):
    # TODO: Connect to WeatherNext 3 API via weather_service
    return {
        "location": {"lat": lat, "lon": lon},
        "temperature_c": 28.5,
        "condition": "Partly Cloudy",
        "humidity": 65,
        "wind_kph": 12.0
    }

@router.get("/forecast")
async def get_forecast(lat: float, lon: float, days: int = 7):
    # TODO: Connect to WeatherNext 3 API
    return {
        "location": {"lat": lat, "lon": lon},
        "forecast": [
            {"day": "Today", "max_temp": 30, "min_temp": 22, "condition": "Sunny"},
            {"day": "Tomorrow", "max_temp": 29, "min_temp": 21, "condition": "Rain"}
        ]
    }
