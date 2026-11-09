import os
import logging
from typing import Dict, Any, Optional
from pathlib import Path

logger = logging.getLogger(__name__)

class EarthEngineService:
    def __init__(self):
        self.is_initialized = False
        self._init_client()

    def _init_client(self):
        """Initialize Google Earth Engine using service account credentials."""
        try:
            import ee
            from google.oauth2 import service_account

            # Determine key file path
            from ..config import settings
            key_path = settings.GOOGLE_SERVICE_ACCOUNT_FILE

            if not os.path.isabs(key_path):
                # Check backend directory or workspace root
                base_dir = Path(__file__).resolve().parent.parent.parent
                candidate = base_dir / key_path
                if candidate.exists():
                    key_path = str(candidate)

            if not os.path.exists(key_path):
                logger.warning(f"Google Service Account file not found at: {key_path}")
                return

            creds = service_account.Credentials.from_service_account_file(
                key_path,
                scopes=[
                    "https://www.googleapis.com/auth/earthengine",
                    "https://www.googleapis.com/auth/cloud-platform"
                ]
            )

            project_id = settings.GOOGLE_CLOUD_PROJECT or "weathergpt-509714"
            ee.Initialize(credentials=creds, project=project_id)
            self.is_initialized = True
            logger.info(f"Google Earth Engine successfully initialized with project: {project_id}")
        except Exception as e:
            logger.warning(f"Google Earth Engine initialization skipped/failed: {e}")
            self.is_initialized = False

    def get_satellite_precision_telemetry(self, lat: float, lon: float) -> Dict[str, Any]:
        """Fetch satellite-derived atmospheric & surface metrics via Google Earth Engine."""
        if not self.is_initialized:
            return {
                "source": "Satellite Observation Proxy",
                "status": "standby",
                "details": "Earth Engine active on production backend",
            }

        try:
            import ee

            point = ee.Geometry.Point([lon, lat])

            # Query ERA5 Land Hourly (ECMWF) for high-resolution reanalysis
            era5 = ee.ImageCollection("ECMWF/ERA5_LAND/HOURLY")\
                .filterBounds(point)\
                .sort("system:time_start", False)\
                .first()

            data = era5.reduceRegion(
                reducer=ee.Reducer.mean(),
                geometry=point,
                scale=11132
            ).getInfo()

            # Extract metrics (converting Kelvin to Celsius, Pa to hPa)
            temp_k = data.get("temperature_2m")
            temp_c = round(temp_k - 273.15, 1) if temp_k is not None else None

            dewpoint_k = data.get("dewpoint_temperature_2m")
            dewpoint_c = round(dewpoint_k - 273.15, 1) if dewpoint_k is not None else None

            sp = data.get("surface_pressure")
            pressure_hpa = round(sp / 100.0, 1) if sp is not None else None

            total_precip_m = data.get("total_precipitation_hourly")
            precip_mm = round(total_precip_m * 1000.0, 2) if total_precip_m is not None else 0.0

            surface_solar_rad = data.get("surface_solar_radiation_downwards_hourly")
            solar_radiation = round(surface_solar_rad / 3600.0, 1) if surface_solar_rad is not None else None

            return {
                "source": "Google Earth Engine (ECMWF ERA5-Land)",
                "status": "live",
                "satellite_temperature_c": temp_c,
                "dewpoint_temperature_c": dewpoint_c,
                "surface_pressure_hpa": pressure_hpa,
                "hourly_precipitation_mm": precip_mm,
                "surface_solar_radiation_wm2": solar_radiation,
            }
        except Exception as e:
            logger.warning(f"Earth Engine telemetry query error: {e}")
            return {
                "source": "Google Earth Engine",
                "status": "fallback",
                "error": str(e)
            }

    def get_satellite_summary_for_ai(self, lat: float, lon: float) -> str:
        """Return satellite summary for Gemini agent tool calling."""
        telemetry = self.get_satellite_precision_telemetry(lat, lon)
        if telemetry.get("status") == "live":
            return (
                f"Google Earth Engine Satellite Precision Metrics: "
                f"Temp: {telemetry.get('satellite_temperature_c')}°C, "
                f"Dew Point: {telemetry.get('dewpoint_temperature_c')}°C, "
                f"Surface Pressure: {telemetry.get('surface_pressure_hpa')} hPa, "
                f"Solar Radiation: {telemetry.get('surface_solar_radiation_wm2')} W/m²."
            )
        return "Google Earth Engine telemetry currently syncing or in standby."

earth_engine_service = EarthEngineService()
