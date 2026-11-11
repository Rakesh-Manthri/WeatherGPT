"""
Unit and API tests for F1.2 Spatial Downscaling Engine.
Run: backend\\venv\\Scripts\\python -m unittest backend\\tests\\test_spatial_downscaling.py -v
"""

import os
import sys
import unittest
from unittest.mock import patch

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from app.services.earth_engine_service import EarthEngineService
from app.services.spatial_downscaling import (
    STANDARD_LAPSE_RATE_C_PER_M,
    SpatialDownscalingEngine,
    _adjust_pressure_hypsometric,
    _rh_from_temp_dewpoint,
)


class TestSpatialDownscalingPhysics(unittest.TestCase):
    def setUp(self):
        self.engine = SpatialDownscalingEngine()

    def test_elevation_lapse_rate_cooling_and_pressure_drop(self):
        # Going 1000m higher from coarse baseline should cool by -6.5 C
        profile = {
            "status": "live",
            "local_elevation_m": 2000.0,
            "local_1km_elevation_m": 1950.0,
            "coarse_grid_elevation_m": 1000.0,
            "slope_deg": 0.0,
            "aspect_deg": 180.0,
            "built_up_fraction": 0.0,
            "tree_cover_fraction": 0.0,
            "vegetation_fraction": 0.0,
            "bare_fraction": 0.0,
            "water_1km_fraction": 0.0,
            "water_10km_fraction": 0.0,
        }
        res = self.engine.downscale_point(
            lat=30.0,
            coarse_temp_c=20.0,
            profile=profile,
            baseline_elevation_m=1000.0,
            wind_speed_kmh=0.0,
            pressure_hpa=900.0,
            is_day=False,
        )
        self.assertAlmostEqual(
            res["adjustments"]["elevation_lapse_c"],
            1000.0 * STANDARD_LAPSE_RATE_C_PER_M,
            places=2,
        )
        self.assertAlmostEqual(res["downscaled_temperature_c"], 13.5, places=1)
        self.assertLess(res["downscaled_pressure_hpa"], 900.0)
        self.assertLess(res["pressure_elevation_delta_hpa"], -90.0)

    def test_urban_heat_island_and_wind_ventilation(self):
        urban_profile = {
            "status": "live",
            "local_elevation_m": 500.0,
            "local_1km_elevation_m": 500.0,
            "coarse_grid_elevation_m": 500.0,
            "slope_deg": 0.0,
            "aspect_deg": 180.0,
            "built_up_fraction": 0.90,
            "tree_cover_fraction": 0.05,
            "vegetation_fraction": 0.08,
            "bare_fraction": 0.0,
            "water_1km_fraction": 0.0,
            "water_10km_fraction": 0.0,
        }
        calm_night = self.engine.downscale_point(
            lat=17.38,
            coarse_temp_c=25.0,
            profile=urban_profile,
            wind_speed_kmh=2.0,
            is_day=False,
        )
        windy_night = self.engine.downscale_point(
            lat=17.38,
            coarse_temp_c=25.0,
            profile=urban_profile,
            wind_speed_kmh=35.0,
            is_day=False,
        )
        self.assertGreater(calm_night["adjustments"]["urban_heat_island_c"], 1.5)
        self.assertGreater(
            calm_night["adjustments"]["urban_heat_island_c"],
            windy_night["adjustments"]["urban_heat_island_c"],
        )

    def test_forest_canopy_daytime_cooling(self):
        forest_profile = {
            "status": "live",
            "local_elevation_m": 500.0,
            "coarse_grid_elevation_m": 500.0,
            "slope_deg": 0.0,
            "aspect_deg": 0.0,
            "built_up_fraction": 0.0,
            "tree_cover_fraction": 0.90,
            "vegetation_fraction": 0.95,
            "bare_fraction": 0.0,
            "water_1km_fraction": 0.0,
            "water_10km_fraction": 0.0,
        }
        day_forest = self.engine.downscale_point(
            lat=11.4,
            coarse_temp_c=24.0,
            profile=forest_profile,
            wind_speed_kmh=5.0,
            is_day=True,
        )
        self.assertLess(day_forest["adjustments"]["vegetation_cooling_c"], -0.7)
        self.assertLess(day_forest["wind_terrain_multiplier"], 0.90)
        self.assertEqual(
            self.engine.classify_microclimate_zone(forest_profile),
            "Dense Forest / Canopy Zone",
        )

    def test_coastal_moderation_sea_breeze_and_nocturnal_inertia(self):
        coastal_profile = {
            "status": "live",
            "local_elevation_m": 5.0,
            "coarse_grid_elevation_m": 5.0,
            "slope_deg": 0.0,
            "aspect_deg": 270.0,
            "built_up_fraction": 0.15,
            "tree_cover_fraction": 0.05,
            "vegetation_fraction": 0.10,
            "bare_fraction": 0.0,
            "water_1km_fraction": 0.45,
            "water_10km_fraction": 0.80,
        }
        hot_day = self.engine.downscale_point(
            lat=18.94,
            coarse_temp_c=35.0,
            profile=coastal_profile,
            wind_speed_kmh=12.0,
            is_day=True,
        )
        cool_night = self.engine.downscale_point(
            lat=18.94,
            coarse_temp_c=12.0,
            profile=coastal_profile,
            wind_speed_kmh=8.0,
            is_day=False,
        )
        self.assertLess(hot_day["adjustments"]["coastal_moderation_c"], -0.5)
        self.assertGreater(cool_night["adjustments"]["coastal_moderation_c"], 0.1)
        self.assertEqual(
            self.engine.classify_microclimate_zone(coastal_profile),
            "Coastal / Maritime Fringe",
        )

    def test_slope_aspect_hemisphere_solar_bias(self):
        slope_profile = {
            "status": "live",
            "local_elevation_m": 1500.0,
            "coarse_grid_elevation_m": 1500.0,
            "slope_deg": 25.0,
            "aspect_deg": 180.0,  # South-facing
            "built_up_fraction": 0.0,
            "tree_cover_fraction": 0.0,
            "vegetation_fraction": 0.2,
            "bare_fraction": 0.0,
            "water_1km_fraction": 0.0,
            "water_10km_fraction": 0.0,
        }
        north_hemi = self.engine.downscale_point(
            lat=32.0,
            coarse_temp_c=18.0,
            profile=slope_profile,
            weather_code=0,
            is_day=True,
        )
        south_hemi = self.engine.downscale_point(
            lat=-32.0,
            coarse_temp_c=18.0,
            profile=slope_profile,
            weather_code=0,
            is_day=True,
        )
        # South-facing slopes warm in Northern Hemisphere and shade-cool in Southern Hemisphere
        self.assertGreater(north_hemi["adjustments"]["topographic_solar_c"], 0.3)
        self.assertLess(south_hemi["adjustments"]["topographic_solar_c"], -0.3)

    def test_worldcover_histogram_parser_handles_empty_ocean(self):
        ocean = EarthEngineService._parse_worldcover_fractions(None, water_fallback=1.0)
        self.assertEqual(ocean["water_fraction"], 1.0)
        self.assertEqual(ocean["built_up_fraction"], 0.0)

        urban = EarthEngineService._parse_worldcover_fractions(
            {"10": 10.0, "50": 80.0, "80": 10.0}
        )
        self.assertAlmostEqual(urban["built_up_fraction"], 0.8)
        self.assertAlmostEqual(urban["tree_cover_fraction"], 0.1)
        self.assertAlmostEqual(urban["water_fraction"], 0.1)

    def test_thermodynamic_helpers(self):
        p_2000m = _adjust_pressure_hypsometric(1013.25, 2000.0, 15.0)
        self.assertTrue(780.0 < p_2000m < 810.0)
        rh = _rh_from_temp_dewpoint(20.0, 20.0)
        self.assertEqual(rh, 100)

    def test_payload_downscaling_hourly_and_coarse_layers(self):
        mock_profile = {
            "status": "live",
            "dem_dataset": "USGS/SRTMGL1_003",
            "landcover_dataset": "ESA/WorldCover/v200",
            "local_elevation_m": 2200.0,
            "local_1km_elevation_m": 2120.0,
            "coarse_grid_elevation_m": 1700.0,
            "slope_deg": 8.0,
            "aspect_deg": 190.0,
            "built_up_fraction": 0.10,
            "tree_cover_fraction": 0.70,
            "vegetation_fraction": 0.85,
            "bare_fraction": 0.0,
            "water_1km_fraction": 0.0,
            "water_10km_fraction": 0.0,
            "cached": False,
        }
        payload = {
            "location_name": "Mountain Peak",
            "latitude": 31.1,
            "longitude": 77.17,
            "model_elevation_m": 2190.0,
            "temperature": 10.0,
            "apparent_temperature": 9.0,
            "humidity": 65,
            "wind_speed": 10.0,
            "pressure": 785.0,
            "precipitation": 0.0,
            "weather_code": 1,
            "is_day": True,
            "temp_max": 14,
            "temp_min": 5,
            "hourly": [
                {"time": "Now", "temp": 10, "wind_speed": 10, "weather_code": 1},
                {"time": "22:00", "temp": 7, "wind_speed": 8, "weather_code": 0},
            ],
            "weathernext_forecast": {
                "status": "live",
                "temperature_2m_c": 13.2,
                "wind_speed_kmh": 11.0,
                "mean_sea_level_pressure_hpa": 1015.0,
                "precipitation_1hr_mm": 0.0,
            },
        }
        with patch.object(self.engine, "get_terrain_profile", return_value=mock_profile):
            out = self.engine.downscale_weather_payload(payload, 31.1, 77.17)

        self.assertIn("spatial_downscaling", out)
        ds_block = out["spatial_downscaling"]
        self.assertEqual(ds_block["status"], "active")
        self.assertEqual(ds_block["microclimate_zone"], "Mountain Ridge / Highland Crest")
        self.assertAlmostEqual(
            ds_block["adjustments"]["district_orographic_bias_c"], -3.25, places=2
        )
        self.assertIn("weathernext_3", ds_block["coarse_model_downscaling"])
        wn_comp = ds_block["coarse_model_downscaling"]["weathernext_3"]
        # Coarse 13.2C @ 1700m drops >3C when downscaled to 2200m
        self.assertLess(wn_comp["downscaled_temp_c"], 10.2)
        # Hourly wind scaled up slightly on exposed ridge despite forest drag
        self.assertEqual(len(out["hourly"]), 2)


class TestSpatialDownscalingEndpoints(unittest.TestCase):
    def test_downscale_custom_coarse_grid_endpoint(self):
        from fastapi.testclient import TestClient
        from app.main import app

        mock_profile = {
            "status": "live",
            "dem_dataset": "USGS/SRTMGL1_003",
            "landcover_dataset": "ESA/WorldCover/v200",
            "local_elevation_m": 2204.0,
            "local_1km_elevation_m": 2114.1,
            "coarse_grid_elevation_m": 1719.4,
            "slope_deg": 6.0,
            "aspect_deg": 201.0,
            "built_up_fraction": 0.26,
            "tree_cover_fraction": 0.70,
            "vegetation_fraction": 0.71,
            "bare_fraction": 0.03,
            "water_1km_fraction": 0.0,
            "water_10km_fraction": 0.0,
            "cached": True,
        }
        client = TestClient(app)
        with patch(
            "app.services.spatial_downscaling.spatial_downscaling_engine.get_terrain_profile",
            return_value=mock_profile,
        ):
            res = client.get(
                "/api/weather/downscale",
                params={
                    "lat": 31.1048,
                    "lon": 77.1734,
                    "coarse_temp_c": 10.6,
                    "coarse_elev_m": 1719.4,
                    "wind_speed_kmh": 8.0,
                    "is_day": False,
                },
            )
        self.assertEqual(res.status_code, 200)
        body = res.json()
        self.assertEqual(body["mode"], "custom_coarse_grid")
        self.assertEqual(body["microclimate_zone"], "Mountain Ridge / Highland Crest")
        self.assertLess(body["downscaled_temperature_c"], 8.0)


if __name__ == "__main__":
    unittest.main()
