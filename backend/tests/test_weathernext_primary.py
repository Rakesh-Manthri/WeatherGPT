import unittest
from backend.app.services.weathernext_service import WeatherNextService
from backend.app.services.weather_service import WeatherService
from backend.app.services.ai_service import get_weathernext_forecast


class TestWeatherNextPrimaryImplementation(unittest.TestCase):
    def setUp(self):
        self.wn_service = WeatherNextService()
        self.weather_service = WeatherService()

    def test_magnus_relative_humidity_calculation(self):
        # At T=30C, Td=20C, RH should be ~55%
        rh = self.wn_service._compute_rh(30.0, 20.0)
        self.assertGreaterEqual(rh, 50)
        self.assertLessEqual(rh, 60)

        # At saturation T=25C, Td=25C, RH should be 100%
        rh_sat = self.wn_service._compute_rh(25.0, 25.0)
        self.assertEqual(rh_sat, 100)

    def test_condition_inference_from_cloud_and_precip(self):
        # Rain condition
        cond_rain, code_rain = self.wn_service._infer_condition(0.9, 2.5, is_day=True)
        self.assertIn("Rain", cond_rain)
        self.assertEqual(code_rain, 63)

        # Overcast condition
        cond_overcast, code_overcast = self.wn_service._infer_condition(0.85, 0.0, is_day=True)
        self.assertEqual(cond_overcast, "Overcast")
        self.assertEqual(code_overcast, 3)

        # Clear Day condition
        cond_clear, code_clear = self.wn_service._infer_condition(0.1, 0.0, is_day=True)
        self.assertEqual(cond_clear, "Clear Sky")
        self.assertEqual(code_clear, 0)

    def test_simulated_ensemble_specifications(self):
        sim = self.wn_service._compute_simulated_ensemble(17.3850, 78.4867)
        self.assertEqual(sim["status"], "live")
        self.assertEqual(sim["ensemble_members"], 64)
        self.assertEqual(sim["grid_resolution_deg"], 0.1)
        self.assertGreater(sim["temperature_ensemble_spread_c"], 0.0)
        self.assertIn("preds", sim["forecast_init"])

    def test_primary_weathernext_payload_assembly(self):
        # Force simulation mode to test primary payload assembly
        from backend.app.config import settings
        original_mode = getattr(settings, "WEATHERNEXT_MODE", "auto")
        try:
            settings.WEATHERNEXT_MODE = "simulation"
            payload = self.wn_service.get_primary_weather_payload(17.3850, 78.4867, "Hyderabad")
            self.assertIsNotNone(payload)
            self.assertTrue(payload["is_weathernext_primary"])
            self.assertIn("WeatherNext 3", payload["data_source"])
            self.assertEqual(payload["ensemble_members"], 64)
            self.assertGreater(len(payload["hourly"]), 0)
            self.assertIn("weathernext_forecast", payload)
        finally:
            settings.WEATHERNEXT_MODE = original_mode

    def test_weather_service_prioritizes_weathernext_or_falls_back_cleanly(self):
        # By default in testing environment, GCS may be standby/fallback or live
        data = self.weather_service.get_structured_weather_data(17.3850, 78.4867, "Hyderabad")
        self.assertIn("temperature", data)
        self.assertIn("data_source", data)
        self.assertIn("is_weathernext_primary", data)
        # Should have valid temperature and location
        self.assertEqual(data["location_name"], "Hyderabad")
        self.assertIsInstance(data["temperature"], (int, float))

    def test_ai_service_resolves_weathernext_query_by_city_name(self):
        res = get_weathernext_forecast("Hyderabad")
        self.assertIsInstance(res, str)
        self.assertIn("WeatherNext 3", res)


if __name__ == "__main__":
    unittest.main()
