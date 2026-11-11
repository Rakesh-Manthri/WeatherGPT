import os
import logging
from collections import OrderedDict
from datetime import datetime, timezone, timedelta
from threading import Lock
from typing import Dict, Any, Optional, Tuple
from pathlib import Path

logger = logging.getLogger(__name__)

class EarthEngineService:
    _TERRAIN_CACHE_MAX_SIZE = 512

    def __init__(self):
        self.is_initialized = False
        self._terrain_cache: OrderedDict[Tuple[float, float], Dict[str, Any]] = OrderedDict()
        self._cache_lock = Lock()
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

            # Query ERA5 Land Hourly (ECMWF) bounded by a recent 45-day window
            # so GEE doesn't scan the entire 1950-present index (~40x faster).
            now_utc = datetime.now(timezone.utc)
            start_str = (now_utc - timedelta(days=45)).strftime("%Y-%m-%d")
            end_str = (now_utc + timedelta(days=2)).strftime("%Y-%m-%d")

            era5 = (
                ee.ImageCollection("ECMWF/ERA5_LAND/HOURLY")
                .filterDate(start_str, end_str)
                .filterBounds(point)
                .sort("system:time_start", False)
                .first()
            )

            data = era5.reduceRegion(
                reducer=ee.Reducer.mean(),
                geometry=point,
                scale=11132
            ).getInfo() or {}

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

    @staticmethod
    def _parse_worldcover_fractions(histogram: Optional[Dict[str, Any]], water_fallback: float = 0.0) -> Dict[str, float]:
        """Convert ESA WorldCover 10m frequency histogram into normalized class fractions."""
        if not histogram:
            if water_fallback >= 0.5:
                return {
                    "built_up_fraction": 0.0,
                    "tree_cover_fraction": 0.0,
                    "vegetation_fraction": 0.0,
                    "bare_fraction": 0.0,
                    "water_fraction": 1.0,
                }
            return {
                "built_up_fraction": 0.0,
                "tree_cover_fraction": 0.0,
                "vegetation_fraction": 0.0,
                "bare_fraction": 0.0,
                "water_fraction": 0.0,
            }

        total = sum(float(v) for v in histogram.values() if v is not None)
        if total <= 0:
            return {
                "built_up_fraction": 0.0,
                "tree_cover_fraction": 0.0,
                "vegetation_fraction": 0.0,
                "bare_fraction": 0.0,
                "water_fraction": round(water_fallback, 4),
            }

        def frac(keys: Tuple[str, ...]) -> float:
            return sum(float(histogram.get(k, 0.0) or 0.0) for k in keys) / total

        built_up = frac(("50",))
        tree_cover = frac(("10", "95"))
        # Vegetated surface = tree canopy + shrubland + grassland + cropland + wetland + mangroves
        vegetation = frac(("10", "20", "30", "40", "90", "95"))
        bare = frac(("60",))
        water = frac(("80",))

        return {
            "built_up_fraction": round(built_up, 4),
            "tree_cover_fraction": round(tree_cover, 4),
            "vegetation_fraction": round(vegetation, 4),
            "bare_fraction": round(bare, 4),
            "water_fraction": round(water, 4),
        }

    def get_microclimate_terrain_profile(self, lat: float, lon: float) -> Dict[str, Any]:
        """
        Fetch hyper-local 30m DEM topography (SRTM GL1 / Copernicus GLO-30) and
        10m land-cover morphology (ESA WorldCover v200) in a single batched GEE call.

        Results are cached by rounded (~110m) coordinate key to keep latency sub-ms
        after the initial (~1s) satellite surface lookup.
        """
        cache_key = (round(lat, 3), round(lon, 3))
        with self._cache_lock:
            cached = self._terrain_cache.get(cache_key)
            if cached is not None:
                self._terrain_cache.move_to_end(cache_key)
                return {**cached, "cached": True}

        if not self.is_initialized:
            return {
                "status": "standby",
                "source": "Fallback Terrain Profile",
                "cached": False,
            }

        try:
            import ee

            point = ee.Geometry.Point([lon, lat])
            use_srtm = -55.0 <= lat <= 58.0

            if use_srtm:
                dem_source = "USGS/SRTMGL1_003"
                dem = ee.Image(dem_source).select("elevation").unmask(0)
            else:
                dem_source = "COPERNICUS/DEM/GLO30_2024_1"
                dem = (
                    ee.ImageCollection(dem_source)
                    .select("DEM")
                    .filterBounds(point.buffer(15000))
                    .mosaic()
                    .rename("elevation")
                    .unmask(0)
                )

            terrain = ee.Terrain.products(dem)
            wc = ee.ImageCollection("ESA/WorldCover/v200").first().select("Map")

            combined = ee.Dictionary({
                "terrain": terrain.reduceRegion(
                    reducer=ee.Reducer.first(),
                    geometry=point,
                    scale=30,
                    maxPixels=1e6,
                ),
                "elev_1km": dem.reduceRegion(
                    reducer=ee.Reducer.mean(),
                    geometry=point.buffer(750),
                    scale=90,
                    maxPixels=1e7,
                ),
                "elev_coarse": dem.reduceRegion(
                    reducer=ee.Reducer.mean(),
                    geometry=point.buffer(12500),
                    scale=1000,
                    maxPixels=1e7,
                ),
                "wc_1km": wc.reduceRegion(
                    reducer=ee.Reducer.frequencyHistogram(),
                    geometry=point.buffer(1000),
                    scale=100,
                    maxPixels=1e7,
                ),
                "water_10km": wc.eq(80).unmask(1).reduceRegion(
                    reducer=ee.Reducer.mean(),
                    geometry=point.buffer(10000),
                    scale=500,
                    maxPixels=1e7,
                ),
            }).getInfo() or {}

            terrain_dict = combined.get("terrain") or {}
            elev_1km_val = (combined.get("elev_1km") or {}).get("elevation")
            elev_coarse_val = (combined.get("elev_coarse") or {}).get("elevation")
            water_10km_val = float((combined.get("water_10km") or {}).get("Map") or 0.0)
            wc_hist = (combined.get("wc_1km") or {}).get("Map")

            local_elev = float(
                terrain_dict.get("elevation")
                if terrain_dict.get("elevation") is not None
                else (elev_1km_val if elev_1km_val is not None else 0.0)
            )
            elev_1km = float(elev_1km_val) if elev_1km_val is not None else local_elev
            elev_coarse = float(elev_coarse_val) if elev_coarse_val is not None else elev_1km

            lc_fractions = self._parse_worldcover_fractions(wc_hist, water_fallback=water_10km_val)

            profile = {
                "status": "live",
                "source": f"Google Earth Engine ({dem_source} + ESA/WorldCover/v200)",
                "dem_dataset": dem_source,
                "landcover_dataset": "ESA/WorldCover/v200",
                "local_elevation_m": round(local_elev, 1),
                "local_1km_elevation_m": round(elev_1km, 1),
                "coarse_grid_elevation_m": round(elev_coarse, 1),
                "slope_deg": round(float(terrain_dict.get("slope") or 0.0), 1),
                "aspect_deg": round(float(terrain_dict.get("aspect") or 0.0), 1),
                "hillshade": round(float(terrain_dict.get("hillshade") or 180.0), 1),
                "built_up_fraction": lc_fractions["built_up_fraction"],
                "tree_cover_fraction": lc_fractions["tree_cover_fraction"],
                "vegetation_fraction": lc_fractions["vegetation_fraction"],
                "bare_fraction": lc_fractions["bare_fraction"],
                "water_1km_fraction": lc_fractions["water_fraction"],
                "water_10km_fraction": round(min(1.0, max(0.0, water_10km_val)), 4),
                "cached": False,
            }

            with self._cache_lock:
                self._terrain_cache[cache_key] = profile
                while len(self._terrain_cache) > self._TERRAIN_CACHE_MAX_SIZE:
                    self._terrain_cache.popitem(last=False)

            return profile

        except Exception as e:
            logger.warning(f"Earth Engine microclimate terrain query error: {e}")
            return {
                "status": "fallback",
                "source": "Fallback Terrain Profile",
                "error": str(e),
                "cached": False,
            }

earth_engine_service = EarthEngineService()
