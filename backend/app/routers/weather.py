from fastapi import APIRouter
from typing import Optional
from ..services.weather_service import weather_service
from ..services.spatial_downscaling import spatial_downscaling_engine

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
        "spatial_downscaling": data.get("spatial_downscaling"),
    }

@router.get("/downscale")
async def downscale_point_weather(
    lat: float,
    lon: float,
    coarse_temp_c: Optional[float] = None,
    coarse_elev_m: Optional[float] = None,
    wind_speed_kmh: Optional[float] = None,
    humidity_pct: Optional[float] = None,
    is_day: Optional[bool] = None,
):
    """
    Hyper-local 1km Spatial Downscaling Engine endpoint.
    If coarse_temp_c is omitted, fetches live regional weather telemetry and
    returns the full 11-25km -> 1km physical & geospatial downscaling breakdown.
    """
    if coarse_temp_c is None:
        data = weather_service.get_structured_weather_data(lat, lon)
        return {
            "location": {"lat": lat, "lon": lon},
            "mode": "live_telemetry",
            "temperature_c": data["temperature"],
            "raw_temperature_c": data.get("raw_temperature", data["temperature"]),
            "wind_kph": data["wind_speed"],
            "pressure_hpa": data["pressure"],
            "spatial_downscaling": data.get("spatial_downscaling"),
        }

    profile = spatial_downscaling_engine.get_terrain_profile(
        lat, lon, fallback_elevation_m=coarse_elev_m
    )
    zone = spatial_downscaling_engine.classify_microclimate_zone(profile)
    result = spatial_downscaling_engine.downscale_point(
        lat=lat,
        coarse_temp_c=coarse_temp_c,
        profile=profile,
        baseline_elevation_m=coarse_elev_m,
        humidity_pct=humidity_pct if humidity_pct is not None else 60.0,
        wind_speed_kmh=wind_speed_kmh if wind_speed_kmh is not None else 10.0,
        is_day=True if is_day is None else is_day,
    )
    return {
        "location": {"lat": lat, "lon": lon},
        "mode": "custom_coarse_grid",
        "microclimate_zone": zone,
        "terrain_profile": profile,
        **result,
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
