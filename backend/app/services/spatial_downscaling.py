"""
Spatial Downscaling Engine (F1.2)

Refines coarse NWP / district-level meteorological grids (11-28 km) down to
1-2 km hyper-local microclimate cells using satellite DEM topography
(SRTM 30m / Copernicus GLO-30) and 10m land-cover morphology (ESA WorldCover v200)
via Google Earth Engine.
"""

import logging
import math
from typing import Any, Dict, List, Optional

from .earth_engine_service import earth_engine_service

logger = logging.getLogger(__name__)

# --- Physical & Thermodynamic Constants ---
STANDARD_LAPSE_RATE_C_PER_M = -0.0065  # Environmental lapse rate (-6.5 C / 1000m)
DEWPOINT_LAPSE_RATE_C_PER_M = -0.0020  # Dewpoint lapse rate (-2.0 C / 1000m)
GRAVITY_MS2 = 9.80665
AIR_MOLAR_MASS_KG_MOL = 0.0289644
UNIVERSAL_GAS_CONSTANT = 8.3144598


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _saturation_vapor_pressure_hpa(temp_c: float) -> float:
    """Alduchov-Eskridge (Magnus) saturation vapor pressure in hPa."""
    return 6.1094 * math.exp((17.625 * temp_c) / (temp_c + 243.04))


def _dewpoint_from_temp_rh(temp_c: float, rh_pct: float) -> float:
    """Compute dewpoint (C) from temperature (C) and relative humidity (%)."""
    rh = _clamp(rh_pct, 1.0, 100.0)
    gamma = math.log(rh / 100.0) + (17.625 * temp_c) / (temp_c + 243.04)
    return (243.04 * gamma) / (17.625 - gamma)


def _rh_from_temp_dewpoint(temp_c: float, dewpoint_c: float) -> int:
    """Compute relative humidity (%) from temperature and dewpoint."""
    es_t = _saturation_vapor_pressure_hpa(temp_c)
    es_td = _saturation_vapor_pressure_hpa(min(dewpoint_c, temp_c))
    rh = (es_td / es_t) * 100.0
    return int(round(_clamp(rh, 5.0, 100.0)))


def _adjust_pressure_hypsometric(
    pressure_hpa: float, delta_z_m: float, mean_temp_c: float
) -> float:
    """Adjust surface pressure (hPa) for an elevation change delta_z_m (m)."""
    if abs(delta_z_m) < 0.5 or pressure_hpa <= 0:
        return round(pressure_hpa, 1)
    temp_k = max(180.0, mean_temp_c + 273.15)
    exponent = -(GRAVITY_MS2 * AIR_MOLAR_MASS_KG_MOL * delta_z_m) / (
        UNIVERSAL_GAS_CONSTANT * temp_k
    )
    return round(pressure_hpa * math.exp(exponent), 1)


def _cloud_attenuation_from_wmo(weather_code: int) -> float:
    """Estimate fractional solar transmission [0.25..1.0] from WMO weather code."""
    if weather_code == 0:
        return 1.0
    if weather_code in (1, 2):
        return 0.8
    if weather_code in (3, 45, 48):
        return 0.4
    return 0.25  # Rain / showers / thunderstorms


def _parse_hour_is_day(time_str: str, fallback_is_day: bool) -> bool:
    """Infer whether an hourly timestamp string falls in daytime [06:00..18:59]."""
    if not time_str or time_str.lower() == "now":
        return fallback_is_day
    try:
        if "T" in time_str:
            hour = int(time_str.split("T")[-1].split(":")[0])
        elif ":" in time_str:
            hour = int(time_str.split(":")[0])
        else:
            return fallback_is_day
        return 6 <= hour < 19
    except (ValueError, IndexError):
        return fallback_is_day


class SpatialDownscalingEngine:
    """
    Physical + Geospatial Microclimate Spatial Downscaler (Coarse 11-28km -> 1km cell).
    Combines GEE SRTM/Copernicus DEM orography and ESA WorldCover 10m land morphology
    with atmospheric thermodynamics.
    """

    def get_terrain_profile(
        self,
        lat: float,
        lon: float,
        fallback_elevation_m: Optional[float] = None,
    ) -> Dict[str, Any]:
        """
        Retrieve GEE microclimate terrain & land-cover profile, falling back cleanly
        to a neutral synthetic profile when Earth Engine is offline/in standby.
        """
        profile = earth_engine_service.get_microclimate_terrain_profile(lat, lon)
        if profile.get("status") == "live":
            return profile

        ref_elev = round(float(fallback_elevation_m), 1) if fallback_elevation_m is not None else 0.0
        return {
            "status": "fallback",
            "source": "Fallback Terrain Profile (DEM Standby)",
            "dem_dataset": "heuristic",
            "landcover_dataset": "heuristic",
            "local_elevation_m": ref_elev,
            "local_1km_elevation_m": ref_elev,
            "coarse_grid_elevation_m": ref_elev,
            "slope_deg": 0.0,
            "aspect_deg": 180.0,
            "hillshade": 180.0,
            "built_up_fraction": 0.25,
            "tree_cover_fraction": 0.15,
            "vegetation_fraction": 0.35,
            "bare_fraction": 0.10,
            "water_1km_fraction": 0.0,
            "water_10km_fraction": 0.0,
            "cached": False,
        }

    @staticmethod
    def classify_microclimate_zone(profile: Dict[str, Any]) -> str:
        """Assign an interpretable geophysical microclimate zone label."""
        elev = float(profile.get("local_elevation_m") or 0.0)
        coarse_elev = float(profile.get("coarse_grid_elevation_m") or elev)
        elev_prominence = elev - coarse_elev

        built_up = float(profile.get("built_up_fraction") or 0.0)
        tree = float(profile.get("tree_cover_fraction") or 0.0)
        veg = float(profile.get("vegetation_fraction") or 0.0)
        water_1km = float(profile.get("water_1km_fraction") or 0.0)
        water_10km = float(profile.get("water_10km_fraction") or 0.0)
        bare = float(profile.get("bare_fraction") or 0.0)

        if elev >= 1400 and elev_prominence >= 100:
            return "Mountain Ridge / Highland Crest"
        if elev >= 900 and elev_prominence <= -80:
            return "Mountain Valley / Basin"
        if elev >= 1400:
            return "High-Altitude Plateau / Hill Terrain"
        if water_10km >= 0.25 and elev < 100:
            return "Coastal / Maritime Fringe"
        if built_up >= 0.60:
            return "High-Density Urban Core"
        if water_1km >= 0.12:
            return "Lakeside / Riverine Buffer"
        if tree >= 0.45:
            return "Dense Forest / Canopy Zone"
        if built_up >= 0.30:
            return "Peri-Urban Mixed Fabric"
        if bare >= 0.40:
            return "Arid / Exposed Surface"
        if veg >= 0.55:
            return "Agricultural / Open Green"
        return "Balanced Continental Cell"

    def downscale_point(
        self,
        *,
        lat: float,
        coarse_temp_c: float,
        profile: Dict[str, Any],
        baseline_elevation_m: Optional[float] = None,
        humidity_pct: float = 60.0,
        wind_speed_kmh: float = 10.0,
        pressure_hpa: float = 1013.0,
        precipitation_mm: float = 0.0,
        weather_code: int = 1,
        is_day: bool = True,
        apparent_temp_c: Optional[float] = None,
    ) -> Dict[str, Any]:
        """
        Compute physically downscaled meteorological values and explicit component deltas
        for a 1 km hyper-local target cell from a coarse reference point.
        """
        local_elev = float(profile.get("local_elevation_m") or 0.0)
        coarse_grid_elev = float(profile.get("coarse_grid_elevation_m") or local_elev)
        ref_elev = (
            float(baseline_elevation_m)
            if baseline_elevation_m is not None
            else coarse_grid_elev
        )

        # 1. Orographic Elevation Lapse Rate Correction (-6.5 C / 1000m)
        delta_z_applied = local_elev - ref_elev
        elevation_lapse_c = delta_z_applied * STANDARD_LAPSE_RATE_C_PER_M

        # District/NWP coarse-to-local elevation contrast (diagnostic & used for coarse grids)
        delta_z_district = local_elev - coarse_grid_elev
        district_orographic_bias_c = delta_z_district * STANDARD_LAPSE_RATE_C_PER_M

        # 2. Urban Heat Island (UHI) & Green Canopy Evapotranspiration Cooling (WorldCover 1km)
        built_up = float(profile.get("built_up_fraction") or 0.0)
        tree_cover = float(profile.get("tree_cover_fraction") or 0.0)
        veg_total = float(profile.get("vegetation_fraction") or 0.0)
        other_veg = max(0.0, veg_total - tree_cover)
        bare_frac = float(profile.get("bare_fraction") or 0.0)

        # Wind ventilation disperses urban heat domes; heavy rain dampens surface contrast
        wind_ventilation = 1.0 / (1.0 + (max(0.0, wind_speed_kmh) / 18.0) ** 1.5)
        precip_damping = 0.45 if precipitation_mm > 0.5 else 1.0

        diurnal_uhi_weight = 0.55 if is_day else 1.0
        raw_uhi_c = (2.6 * built_up * diurnal_uhi_weight) + (
            0.5 * bare_frac * (0.9 if is_day else -0.4)
        )
        urban_heat_island_c = _clamp(
            raw_uhi_c * wind_ventilation * precip_damping, -0.5, 2.8
        )

        diurnal_veg_weight = 0.90 if is_day else 0.40
        raw_veg_cooling_c = -(1.3 * tree_cover + 0.5 * other_veg) * diurnal_veg_weight
        vegetation_cooling_c = _clamp(
            raw_veg_cooling_c * (0.5 + 0.5 * wind_ventilation) * precip_damping,
            -1.4,
            0.0,
        )

        # 3. Coastal & Water Thermal Moderation (WorldCover water at 1km & 10km)
        water_1km = float(profile.get("water_1km_fraction") or 0.0)
        water_10km = float(profile.get("water_10km_fraction") or 0.0)
        maritime_index = _clamp(0.45 * water_1km + 0.55 * water_10km, 0.0, 1.0)

        coastal_moderation_c = 0.0
        if maritime_index > 0.05:
            if is_day and coarse_temp_c > 25.0:
                # Afternoon sea/lake breeze cools warm coastal strips
                thermal_excess = min(14.0, coarse_temp_c - 25.0) / 14.0
                coastal_moderation_c = -1.6 * maritime_index * (0.4 + 0.6 * thermal_excess)
            elif not is_day and coarse_temp_c < 20.0:
                # High heat capacity of adjacent water buffers nocturnal cooling
                cool_deficit = min(15.0, 20.0 - coarse_temp_c) / 15.0
                coastal_moderation_c = 0.9 * maritime_index * cool_deficit
            elif is_day and coarse_temp_c <= 25.0:
                coastal_moderation_c = -0.35 * maritime_index

        # 4. Topographic Slope / Aspect Direct Solar Adjustment
        slope_deg = float(profile.get("slope_deg") or 0.0)
        aspect_deg = float(profile.get("aspect_deg") or 180.0)
        topographic_solar_c = 0.0
        if is_day and slope_deg > 2.0 and abs(lat) > 5.0:
            # Northern hemisphere south-facing (180 deg) receives extra direct radiation;
            # Southern hemisphere north-facing (0 deg) receives extra direct radiation.
            preferred_aspect = 180.0 if lat >= 0 else 0.0
            aspect_alignment = math.cos(math.radians(aspect_deg - preferred_aspect))
            slope_strength = min(1.0, slope_deg / 30.0)
            solar_transmission = _cloud_attenuation_from_wmo(weather_code)
            topographic_solar_c = _clamp(
                0.7 * aspect_alignment * slope_strength * solar_transmission,
                -0.65,
                0.65,
            )

        # Total temperature correction
        net_temp_delta_c = (
            elevation_lapse_c
            + urban_heat_island_c
            + vegetation_cooling_c
            + coastal_moderation_c
            + topographic_solar_c
        )
        downscaled_temp_c = round(coarse_temp_c + net_temp_delta_c, 1)

        # 5. Wind Terrain Exposure & Surface Aerodynamic Roughness Adjustment
        # Ridgetops accelerate airflow; dense forests/high-rise cities add frictional drag;
        # coastlines enjoy stronger sea-breeze airflow.
        topo_exposure_factor = 1.0 + _clamp(delta_z_district / 600.0, -0.18, 0.25)
        roughness_drag = 1.0 - _clamp(0.18 * tree_cover + 0.14 * built_up, 0.0, 0.22)
        sea_breeze_boost = 1.0 + (0.14 * maritime_index if is_day else 0.05 * maritime_index)
        wind_multiplier = _clamp(
            topo_exposure_factor * roughness_drag * sea_breeze_boost, 0.65, 1.35
        )
        downscaled_wind_kmh = round(max(0.0, wind_speed_kmh * wind_multiplier), 1)

        # 6. Hypsometric Surface Pressure Correction
        mean_col_temp = (coarse_temp_c + downscaled_temp_c) * 0.5
        downscaled_pressure_hpa = _adjust_pressure_hypsometric(
            pressure_hpa, delta_z_applied, mean_col_temp
        )
        pressure_delta_hpa = round(downscaled_pressure_hpa - pressure_hpa, 1)

        # 7. Thermodynamic Dewpoint, Humidity & Apparent Temperature Consistency
        raw_dewpoint_c = _dewpoint_from_temp_rh(coarse_temp_c, humidity_pct)
        downscaled_dewpoint_c = round(
            raw_dewpoint_c + (delta_z_applied * DEWPOINT_LAPSE_RATE_C_PER_M), 1
        )
        downscaled_humidity = _rh_from_temp_dewpoint(downscaled_temp_c, downscaled_dewpoint_c)

        base_apparent = apparent_temp_c if apparent_temp_c is not None else coarse_temp_c
        # Differential wind-chill / convective cooling adjustment on apparent temp
        wind_delta_ms = (downscaled_wind_kmh - wind_speed_kmh) / 3.6
        downscaled_apparent_c = round(
            base_apparent + (downscaled_temp_c - coarse_temp_c) - (0.35 * wind_delta_ms),
            1,
        )

        return {
            "raw_temperature_c": round(coarse_temp_c, 1),
            "downscaled_temperature_c": downscaled_temp_c,
            "downscaled_apparent_temperature_c": downscaled_apparent_c,
            "downscaled_dewpoint_c": downscaled_dewpoint_c,
            "downscaled_humidity_pct": downscaled_humidity,
            "downscaled_wind_speed_kmh": downscaled_wind_kmh,
            "downscaled_pressure_hpa": downscaled_pressure_hpa,
            "net_temperature_delta_c": round(net_temp_delta_c, 2),
            "wind_terrain_multiplier": round(wind_multiplier, 3),
            "pressure_elevation_delta_hpa": pressure_delta_hpa,
            "adjustments": {
                "elevation_lapse_c": round(elevation_lapse_c, 2),
                "district_orographic_bias_c": round(district_orographic_bias_c, 2),
                "urban_heat_island_c": round(urban_heat_island_c, 2),
                "vegetation_cooling_c": round(vegetation_cooling_c, 2),
                "coastal_moderation_c": round(coastal_moderation_c, 2),
                "topographic_solar_c": round(topographic_solar_c, 2),
            },
            "reference_elevation_m": round(ref_elev, 1),
            "target_elevation_m": round(local_elev, 1),
            "coarse_grid_elevation_m": round(coarse_grid_elev, 1),
            "maritime_index": round(maritime_index, 3),
        }

    def downscale_weather_payload(
        self, weather_data: Dict[str, Any], lat: float, lon: float
    ) -> Dict[str, Any]:
        """
        Apply hyper-local spatial downscaling to a structured weather telemetry dict
        (including current metrics, daily min/max, hourly points, and coarse NWP layers).
        """
        raw_temp = float(weather_data.get("temperature") or 27.0)
        raw_apparent = float(weather_data.get("apparent_temperature") or raw_temp)
        raw_humidity = float(weather_data.get("humidity") or 60.0)
        raw_wind = float(weather_data.get("wind_speed") or 10.0)
        raw_pressure = float(weather_data.get("pressure") or 1013.0)
        raw_precip = float(weather_data.get("precipitation") or 0.0)
        wmo_code = int(weather_data.get("weather_code") or 1)
        is_day = bool(weather_data.get("is_day", True))
        model_elev = weather_data.get("model_elevation_m")

        profile = self.get_terrain_profile(
            lat,
            lon,
            fallback_elevation_m=float(model_elev) if model_elev is not None else None,
        )
        zone = self.classify_microclimate_zone(profile)

        current_ds = self.downscale_point(
            lat=lat,
            coarse_temp_c=raw_temp,
            profile=profile,
            baseline_elevation_m=float(model_elev) if model_elev is not None else None,
            humidity_pct=raw_humidity,
            wind_speed_kmh=raw_wind,
            pressure_hpa=raw_pressure,
            precipitation_mm=raw_precip,
            weather_code=wmo_code,
            is_day=is_day,
            apparent_temp_c=raw_apparent,
        )

        # Preserve raw baseline metrics before updating top-level fields
        updated = dict(weather_data)
        updated["raw_temperature"] = round(raw_temp, 1)
        updated["temperature"] = current_ds["downscaled_temperature_c"]
        updated["apparent_temperature"] = current_ds["downscaled_apparent_temperature_c"]
        updated["humidity"] = current_ds["downscaled_humidity_pct"]
        updated["wind_speed"] = current_ds["downscaled_wind_speed_kmh"]
        updated["pressure"] = current_ds["downscaled_pressure_hpa"]

        # Adjust daily max (daytime bias) and min (nocturnal bias) cleanly
        raw_max = weather_data.get("temp_max")
        raw_min = weather_data.get("temp_min")
        if raw_max is not None:
            day_ds = self.downscale_point(
                lat=lat,
                coarse_temp_c=float(raw_max),
                profile=profile,
                baseline_elevation_m=float(model_elev) if model_elev is not None else None,
                humidity_pct=raw_humidity,
                wind_speed_kmh=raw_wind,
                pressure_hpa=raw_pressure,
                precipitation_mm=raw_precip,
                weather_code=wmo_code,
                is_day=True,
            )
            updated["temp_max"] = round(day_ds["downscaled_temperature_c"])
        if raw_min is not None:
            night_ds = self.downscale_point(
                lat=lat,
                coarse_temp_c=float(raw_min),
                profile=profile,
                baseline_elevation_m=float(model_elev) if model_elev is not None else None,
                humidity_pct=raw_humidity,
                wind_speed_kmh=raw_wind,
                pressure_hpa=raw_pressure,
                precipitation_mm=0.0,
                weather_code=wmo_code,
                is_day=False,
            )
            updated["temp_min"] = round(night_ds["downscaled_temperature_c"])

        # Downscale each hourly point consistently for its local hour-of-day
        hourly_items = weather_data.get("hourly") or []
        if hourly_items:
            downscaled_hourly: List[Dict[str, Any]] = []
            for item in hourly_items:
                h_temp = float(item.get("temp") if item.get("temp") is not None else raw_temp)
                h_wind = float(
                    item.get("wind_speed") if item.get("wind_speed") is not None else raw_wind
                )
                h_code = int(item.get("weather_code") if item.get("weather_code") is not None else wmo_code)
                h_is_day = _parse_hour_is_day(str(item.get("time") or ""), is_day)
                h_ds = self.downscale_point(
                    lat=lat,
                    coarse_temp_c=h_temp,
                    profile=profile,
                    baseline_elevation_m=float(model_elev) if model_elev is not None else None,
                    humidity_pct=raw_humidity,
                    wind_speed_kmh=h_wind,
                    pressure_hpa=raw_pressure,
                    precipitation_mm=0.0,
                    weather_code=h_code,
                    is_day=h_is_day,
                )
                new_item = dict(item)
                new_item["temp"] = round(h_ds["downscaled_temperature_c"])
                new_item["wind_speed"] = round(h_ds["downscaled_wind_speed_kmh"])
                downscaled_hourly.append(new_item)
            updated["hourly"] = downscaled_hourly

        # Also downscale coarse ~11km NWP/Reanalysis layers against coarse_grid_elevation_m
        coarse_ref_comparisons: Dict[str, Any] = {}
        wn = weather_data.get("weathernext_forecast")
        if isinstance(wn, dict) and wn.get("status") == "live" and wn.get("temperature_2m_c") is not None:
            wn_ds = self.downscale_point(
                lat=lat,
                coarse_temp_c=float(wn["temperature_2m_c"]),
                profile=profile,
                baseline_elevation_m=float(profile.get("coarse_grid_elevation_m") or 0.0),
                humidity_pct=raw_humidity,
                wind_speed_kmh=float(wn.get("wind_speed_kmh") or raw_wind),
                pressure_hpa=float(wn.get("mean_sea_level_pressure_hpa") or raw_pressure),
                precipitation_mm=float(wn.get("precipitation_1hr_mm") or 0.0),
                weather_code=wmo_code,
                is_day=is_day,
            )
            coarse_ref_comparisons["weathernext_3"] = {
                "coarse_temp_c": wn["temperature_2m_c"],
                "downscaled_temp_c": wn_ds["downscaled_temperature_c"],
                "delta_c": wn_ds["net_temperature_delta_c"],
                "resolution_shift": "0.1° (~11 km) -> 1 km",
            }

        sat = weather_data.get("satellite_telemetry")
        if isinstance(sat, dict) and sat.get("status") == "live" and sat.get("satellite_temperature_c") is not None:
            sat_ds = self.downscale_point(
                lat=lat,
                coarse_temp_c=float(sat["satellite_temperature_c"]),
                profile=profile,
                baseline_elevation_m=float(profile.get("coarse_grid_elevation_m") or 0.0),
                humidity_pct=raw_humidity,
                wind_speed_kmh=raw_wind,
                pressure_hpa=float(sat.get("surface_pressure_hpa") or raw_pressure),
                precipitation_mm=float(sat.get("hourly_precipitation_mm") or 0.0),
                weather_code=wmo_code,
                is_day=is_day,
            )
            coarse_ref_comparisons["era5_land"] = {
                "coarse_temp_c": sat["satellite_temperature_c"],
                "downscaled_temp_c": sat_ds["downscaled_temperature_c"],
                "delta_c": sat_ds["net_temperature_delta_c"],
                "resolution_shift": "~11 km -> 1 km",
            }

        updated["spatial_downscaling"] = {
            "status": "active" if profile.get("status") == "live" else "fallback",
            "engine": "WeatherGPT Spatial Downscaling Engine v1.0",
            "source_resolution": "11-25 km coarse NWP / DEM grid",
            "target_resolution": "1 km hyper-local microclimate cell (30m SRTM / 10m WorldCover)",
            "microclimate_zone": zone,
            "raw_temperature_c": current_ds["raw_temperature_c"],
            "downscaled_temperature_c": current_ds["downscaled_temperature_c"],
            "net_temperature_delta_c": current_ds["net_temperature_delta_c"],
            "wind_terrain_multiplier": current_ds["wind_terrain_multiplier"],
            "pressure_elevation_delta_hpa": current_ds["pressure_elevation_delta_hpa"],
            "adjustments": current_ds["adjustments"],
            "terrain_profile": {
                "dem_dataset": profile.get("dem_dataset"),
                "landcover_dataset": profile.get("landcover_dataset"),
                "local_elevation_m": profile.get("local_elevation_m"),
                "local_1km_elevation_m": profile.get("local_1km_elevation_m"),
                "coarse_grid_elevation_m": profile.get("coarse_grid_elevation_m"),
                "model_reference_elevation_m": current_ds["reference_elevation_m"],
                "slope_deg": profile.get("slope_deg"),
                "aspect_deg": profile.get("aspect_deg"),
                "built_up_pct": round(float(profile.get("built_up_fraction") or 0.0) * 100.0, 1),
                "tree_cover_pct": round(float(profile.get("tree_cover_fraction") or 0.0) * 100.0, 1),
                "vegetation_pct": round(float(profile.get("vegetation_fraction") or 0.0) * 100.0, 1),
                "water_10km_pct": round(float(profile.get("water_10km_fraction") or 0.0) * 100.0, 1),
                "cached": profile.get("cached", False),
            },
            "coarse_model_downscaling": coarse_ref_comparisons,
        }

        return updated

    def format_for_ai(self, ds_block: Optional[Dict[str, Any]]) -> str:
        """Build a concise meteorological summary of the 1 km downscaling result for Gemini."""
        if not ds_block:
            return "Spatial downscaling telemetry unavailable."

        adj = ds_block.get("adjustments", {})
        tp = ds_block.get("terrain_profile", {})
        zone = ds_block.get("microclimate_zone", "Microclimate Cell")
        net_delta = ds_block.get("net_temperature_delta_c", 0.0)
        sign = "+" if net_delta >= 0 else ""

        return (
            f"Hyper-Local 1km Spatial Downscaling ({ds_block.get('status', 'active').upper()}): "
            f"Zone='{zone}', Elevation={tp.get('local_elevation_m')}m "
            f"(25km district grid avg={tp.get('coarse_grid_elevation_m')}m, "
            f"slope={tp.get('slope_deg')}deg), "
            f"LandCover={tp.get('built_up_pct')}% urban / {tp.get('tree_cover_pct')}% trees / "
            f"{tp.get('water_10km_pct')}% coastal water(10km). "
            f"Downscaled Temp={ds_block.get('downscaled_temperature_c')}°C "
            f"(Raw={ds_block.get('raw_temperature_c')}°C, Net={sign}{net_delta}°C: "
            f"UHI={adj.get('urban_heat_island_c')}°C, Canopy={adj.get('vegetation_cooling_c')}°C, "
            f"Coastal={adj.get('coastal_moderation_c')}°C, ElevLapse={adj.get('elevation_lapse_c')}°C, "
            f"DistrictOrographicBias={adj.get('district_orographic_bias_c')}°C, "
            f"WindMult={ds_block.get('wind_terrain_multiplier')}x)."
        )


spatial_downscaling_engine = SpatialDownscalingEngine()
