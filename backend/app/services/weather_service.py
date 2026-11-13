import httpx
import logging
import math
from typing import Dict, Any, List, Tuple
from datetime import datetime, timezone, timedelta
from .earth_engine_service import earth_engine_service
from .weathernext_service import weathernext_service
from .spatial_downscaling import spatial_downscaling_engine

logger = logging.getLogger(__name__)

class WeatherService:
    def __init__(self):
        self.base_url = "https://api.open-meteo.com/v1/forecast"
        self.aqi_url = "https://air-quality-api.open-meteo.com/v1/air-quality"
        self.nominatim_url = "https://nominatim.openstreetmap.org/reverse"
        self._geocode_cache: Dict[Tuple[float, float], str] = {}
        self._headers = {"User-Agent": "WeatherGPT-App/1.0 (contact@weathergpt.local)"}

    def _reverse_geocode_city(self, lat: float, lon: float) -> str:
        """Resolve coordinate pair into a human-readable city or district name."""
        key = (round(lat, 2), round(lon, 2))
        if key in self._geocode_cache:
            return self._geocode_cache[key]
        try:
            with httpx.Client(timeout=3.0, headers=self._headers) as client:
                resp = client.get(
                    self.nominatim_url,
                    params={"lat": lat, "lon": lon, "format": "json", "zoom": 10},
                )
                if resp.status_code == 200:
                    data = resp.json()
                    addr = data.get("address", {})
                    city = (
                        addr.get("city")
                        or addr.get("town")
                        or addr.get("village")
                        or addr.get("municipality")
                        or addr.get("county")
                        or addr.get("state_district")
                        or data.get("name")
                    )
                    if city:
                        self._geocode_cache[key] = str(city)
                        return str(city)
        except Exception as e:
            logger.debug(f"Reverse geocoding skipped for ({lat}, {lon}): {e}")
        return ""

    def _compute_dynamic_climatological_fallback(
        self, lat: float, lon: float, location_name: str = ""
    ) -> Dict[str, Any]:
        """
        Solar/latitude-aware dynamic meteorological approximation when live APIs are unreachable.
        Calculates diurnal cycle, solar elevation, and latitude gradients instead of hardcoded constants.
        """
        now_utc = datetime.now(timezone.utc)
        # Approximate local solar hour using longitude (15 deg per hour)
        local_solar_hour = (now_utc.hour + now_utc.minute / 60.0 + lon / 15.0) % 24.0

        # Baseline temperature scaled by latitude (equatorial warmth ~31C to temperate ~12C)
        lat_base = max(8.0, 31.0 - abs(lat) * 0.42)
        # Diurnal fluctuation: peak at 14:00 (+4.5C), minimum at 05:00 (-4.5C)
        diurnal_rad = math.radians((local_solar_hour - 14.0) * 15.0)
        diurnal = 4.8 * math.cos(diurnal_rad)

        temp = round(lat_base + diurnal, 1)
        apparent = round(temp + 1.2 if diurnal > 0 else temp - 0.5, 1)
        is_day = 6.0 <= local_solar_hour <= 18.5
        condition = "Clear Sky" if is_day else "Clear Night"
        w_code = 0 if is_day else 1

        resolved_name = location_name or self._reverse_geocode_city(lat, lon) or "Local Area"

        return {
            "location_name": resolved_name,
            "latitude": lat,
            "longitude": lon,
            "temperature": temp,
            "apparent_temperature": apparent,
            "condition": condition,
            "weather_code": w_code,
            "humidity": 55 if diurnal > 0 else 72,
            "wind_speed": 9.5,
            "wind_direction": 180,
            "wind_gusts": 13.0,
            "precipitation": 0.0,
            "pressure": 1013.0,
            "uv_index": round(max(0.0, 6.5 * math.sin(math.radians((local_solar_hour - 6.0) / 12.0 * 180.0))), 1) if is_day else 0.0,
            "is_day": is_day,
            "temp_max": round(lat_base + 4.8),
            "temp_min": round(lat_base - 4.8),
            "rain_chance": 5,
            "aqi": 58,
            "is_simulated_fallback": True,
            "hourly": [
                {"time": "Now", "temp": round(temp), "rain_chance": 0, "weather_code": w_code, "wind_speed": 10},
                {"time": "06:00", "temp": round(lat_base - 4.0), "rain_chance": 0, "weather_code": 0, "wind_speed": 8},
                {"time": "12:00", "temp": round(lat_base + 3.5), "rain_chance": 5, "weather_code": 1, "wind_speed": 12},
                {"time": "15:00", "temp": round(lat_base + 4.5), "rain_chance": 5, "weather_code": 1, "wind_speed": 13},
                {"time": "18:00", "temp": round(lat_base + 1.0), "rain_chance": 0, "weather_code": 1, "wind_speed": 10},
                {"time": "21:00", "temp": round(lat_base - 2.5), "rain_chance": 0, "weather_code": 0, "wind_speed": 8},
            ],
        }

    def _map_wmo_code(self, code: int) -> str:
        if code == 0:
            return "Clear Sky"
        elif code in [1, 2]:
            return "Partly Cloudy"
        elif code == 3:
            return "Overcast"
        elif code in [45, 48]:
            return "Foggy"
        elif code in [51, 53, 55]:
            return "Drizzle"
        elif code in [61, 63, 65]:
            return "Rain"
        elif code in [71, 73, 75]:
            return "Snow"
        elif code in [80, 81, 82]:
            return "Showers"
        elif code in [95, 96, 99]:
            return "Thunderstorm"
        return "Partly Cloudy"

    def get_structured_weather_data(self, lat: float, lon: float, location_name: str = "") -> Dict[str, Any]:
        """Fetch comprehensive telemetry and forecast data with resilient fallbacks and decoupled satellite telemetry."""
        # 1. Resolve human-readable location name if absent
        resolved_name = location_name
        if not resolved_name or resolved_name == "Your Location":
            resolved_name = self._reverse_geocode_city(lat, lon) or "Your Location"

        payload: Optional[Dict[str, Any]] = None

        # 2. Fetch Open-Meteo telemetry with retry and generous timeout
        params = {
            "latitude": lat,
            "longitude": lon,
            "current": [
                "temperature_2m", "relative_humidity_2m", "apparent_temperature",
                "is_day", "precipitation", "weather_code", "surface_pressure",
                "wind_speed_10m", "wind_direction_10m", "wind_gusts_10m", "uv_index"
            ],
            "hourly": ["temperature_2m", "precipitation_probability", "weather_code", "wind_speed_10m"],
            "daily": [
                "weather_code", "temperature_2m_max", "temperature_2m_min",
                "precipitation_probability_max", "sunrise", "sunset"
            ],
            "timezone": "auto"
        }

        data: Optional[Dict[str, Any]] = None
        for attempt in range(2):
            try:
                with httpx.Client(timeout=8.0, headers=self._headers) as client:
                    resp = client.get(self.base_url, params=params)
                    resp.raise_for_status()
                    data = resp.json()
                    break
            except Exception as exc:
                logger.warning(f"Open-Meteo attempt {attempt + 1} failed for ({lat}, {lon}): {exc}")

        if data:
            try:
                current = data.get("current") or {}
                daily = data.get("daily") or {}
                hourly = data.get("hourly") or {}

                # Safely parse daily metrics with null-guarding
                t_max_list = daily.get("temperature_2m_max")
                temp_max = round(float(t_max_list[0])) if t_max_list and t_max_list[0] is not None else 31.0
                t_min_list = daily.get("temperature_2m_min")
                temp_min = round(float(t_min_list[0])) if t_min_list and t_min_list[0] is not None else 21.0
                rain_ch_list = daily.get("precipitation_probability_max")
                rain_chance = int(rain_ch_list[0]) if rain_ch_list and rain_ch_list[0] is not None else 5

                # Parse hourly next 12 hours
                hourly_list: List[Dict[str, Any]] = []
                times = hourly.get("time") or []
                temps = hourly.get("temperature_2m") or []
                precips = hourly.get("precipitation_probability") or []
                codes = hourly.get("weather_code") or []
                winds = hourly.get("wind_speed_10m") or []

                current_hour_iso = datetime.now().strftime("%Y-%m-%dT%H:00")
                start_idx = 0
                for i, t in enumerate(times):
                    if t >= current_hour_iso:
                        start_idx = i
                        break

                for i in range(start_idx, min(start_idx + 12, len(times))):
                    t_str = times[i]
                    hour_label = t_str.split("T")[-1] if "T" in t_str else t_str
                    hourly_list.append({
                        "time": "Now" if i == start_idx else hour_label,
                        "temp": round(float(temps[i])) if i < len(temps) and temps[i] is not None else 25,
                        "rain_chance": int(precips[i]) if i < len(precips) and precips[i] is not None else 0,
                        "weather_code": int(codes[i]) if i < len(codes) and codes[i] is not None else 0,
                        "wind_speed": round(float(winds[i])) if i < len(winds) and winds[i] is not None else 10,
                    })

                code = int(current.get("weather_code", 1))
                condition = self._map_wmo_code(code)

                # AQI lookup in safe isolated block
                aqi = 55
                try:
                    with httpx.Client(timeout=3.0, headers=self._headers) as client:
                        aqi_resp = client.get(self.aqi_url, params={
                            "latitude": lat, "longitude": lon, "current": ["us_aqi"], "timezone": "auto"
                        })
                        if aqi_resp.status_code == 200:
                            aqi = aqi_resp.json().get("current", {}).get("us_aqi", 55)
                except Exception:
                    pass

                # Decoupled satellite telemetry (isolated try/catch so GEE failure never affects core weather)
                satellite_telemetry = None
                if earth_engine_service.is_initialized:
                    try:
                        satellite_telemetry = earth_engine_service.get_satellite_precision_telemetry(lat, lon)
                    except Exception as sat_err:
                        logger.debug(f"Earth Engine telemetry skipped: {sat_err}")

                # Decoupled WeatherNext forecast (isolated try/catch so GCS failure never affects core weather)
                weathernext_forecast = None
                if weathernext_service.is_initialized:
                    try:
                        weathernext_forecast = weathernext_service.get_forecast(lat, lon)
                    except Exception as wn_err:
                        logger.debug(f"WeatherNext forecast skipped: {wn_err}")

                payload = {
                    "location_name": resolved_name,
                    "latitude": lat,
                    "longitude": lon,
                    "model_elevation_m": data.get("elevation"),
                    "temperature": round(float(current.get("temperature_2m", 25.0)), 1),
                    "apparent_temperature": round(float(current.get("apparent_temperature", 26.0)), 1),
                    "condition": condition,
                    "weather_code": code,
                    "humidity": current.get("relative_humidity_2m", 60),
                    "wind_speed": round(float(current.get("wind_speed_10m", 10.0)), 1),
                    "wind_direction": current.get("wind_direction_10m", 180),
                    "wind_gusts": round(float(current.get("wind_gusts_10m", 12.0)), 1),
                    "precipitation": float(current.get("precipitation", 0.0)),
                    "pressure": round(float(current.get("surface_pressure", 1013.0)), 1),
                    "uv_index": float(current.get("uv_index", 5.0)),
                    "is_day": current.get("is_day", 1) == 1,
                    "temp_max": temp_max,
                    "temp_min": temp_min,
                    "rain_chance": rain_chance,
                    "aqi": aqi,
                    "hourly": hourly_list,
                    "satellite_telemetry": satellite_telemetry,
                    "weathernext_forecast": weathernext_forecast,
                }
            except Exception as parse_err:
                logger.error(f"Error parsing live Open-Meteo payload: {parse_err}")

        # 3. If live telemetry failed completely, generate solar/latitude-dynamic approximation
        if not payload:
            logger.warning(f"Using dynamic climatological approximation for ({lat}, {lon})")
            payload = self._compute_dynamic_climatological_fallback(lat, lon, location_name=resolved_name)

        # 4. Apply Spatial Downscaling Engine (1km hyper-local physics)
        try:
            payload = spatial_downscaling_engine.downscale_weather_payload(payload, lat, lon)
        except Exception as ds_err:
            logger.warning(f"Spatial downscaling skipped due to error: {ds_err}")

        return payload

    def get_current_conditions(self, lat: float, lon: float) -> str:
        """Fetch current conditions string for AI agent function calling."""
        data = self.get_structured_weather_data(lat, lon)
        base = (
            f"Weather Data (1km Downscaled): {data['temperature']}°C "
            f"(Feels like {data['apparent_temperature']}°C), "
            f"{data['condition']}, High: {data['temp_max']}°C, Low: {data['temp_min']}°C, "
            f"Humidity {data['humidity']}%, Wind {data['wind_speed']} km/h, Rain chance {data['rain_chance']}%, "
            f"AQI {data['aqi']}."
        )
        ds = data.get("spatial_downscaling")
        if ds:
            return f"{base} {spatial_downscaling_engine.format_for_ai(ds)}"
        return base

    def get_daily_forecast_list(self, lat: float, lon: float, days: int = 7) -> List[Dict[str, Any]]:
        """Fetch lightweight multi-day forecast list (for multi-day Panchangam & Weather window fusion)."""
        days = max(1, min(14, days))
        try:
            params = {
                "latitude": lat,
                "longitude": lon,
                "daily": [
                    "weather_code",
                    "temperature_2m_max",
                    "temperature_2m_min",
                    "precipitation_probability_max",
                    "wind_speed_10m_max",
                ],
                "forecast_days": days,
                "timezone": "auto",
            }
            with httpx.Client(timeout=8.0, headers=self._headers) as client:
                resp = client.get(self.base_url, params=params)
                resp.raise_for_status()
                daily = resp.json().get("daily", {})

            dates = daily.get("time", [])
            codes = daily.get("weather_code", [])
            t_max = daily.get("temperature_2m_max", [])
            t_min = daily.get("temperature_2m_min", [])
            rain_p = daily.get("precipitation_probability_max", [])
            winds = daily.get("wind_speed_10m_max", [])

            results: List[Dict[str, Any]] = []
            for i, d_str in enumerate(dates[:days]):
                code = int(codes[i]) if i < len(codes) and codes[i] is not None else 1
                results.append({
                    "date": d_str,
                    "weather_code": code,
                    "condition": self._map_wmo_code(code),
                    "temp_max": round(float(t_max[i]), 1) if i < len(t_max) and t_max[i] is not None else 29.0,
                    "temp_min": round(float(t_min[i]), 1) if i < len(t_min) and t_min[i] is not None else 19.0,
                    "rain_chance": int(rain_p[i]) if i < len(rain_p) and rain_p[i] is not None else 10,
                    "wind_speed_max": round(float(winds[i]), 1) if i < len(winds) and winds[i] is not None else 12.0,
                })
            if results:
                return results
        except Exception as exc:
            logger.warning(f"Daily forecast fetch failed, using synthetic 7-day baseline: {exc}")

        today = datetime.now().date()
        lat_base = max(8.0, 31.0 - abs(lat) * 0.42)
        return [
            {
                "date": (today + timedelta(days=i)).isoformat(),
                "weather_code": 1,
                "condition": "Partly Cloudy",
                "temp_max": round(lat_base + 4.5, 1),
                "temp_min": round(lat_base - 4.5, 1),
                "rain_chance": 10,
                "wind_speed_max": 12.0,
            }
            for i in range(days)
        ]

weather_service = WeatherService()

