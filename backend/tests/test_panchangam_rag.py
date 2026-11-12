"""
Unit & API tests for F2.1 Hybrid RAG Pipeline: Panchangam + Weather.
Run: backend\\venv\\Scripts\\python -m unittest backend\\tests\\test_panchangam_rag.py -v
"""

import os
import sys
import unittest
from datetime import date
from unittest.mock import patch

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from app.services.panchangam_service import (
    PanchangamService,
    is_panchangam_query,
)


class TestPanchangamAstronomyAndRag(unittest.TestCase):
    def setUp(self):
        self.svc = PanchangamService()

    def test_intent_detector_english_and_indic(self):
        self.assertTrue(is_panchangam_query("Show today's Panchangam and Tithi"))
        self.assertTrue(is_panchangam_query("Is tomorrow good for sowing crops?"))
        self.assertTrue(is_panchangam_query("Best Muhurtham for outdoor wedding"))
        self.assertTrue(is_panchangam_query("Will it rain during Ugadi?"))
        self.assertTrue(is_panchangam_query("आज का पंचांग और मुहूर्त बताओ"))
        self.assertTrue(is_panchangam_query("ఈ రోజు తిథి మరియు ముహూర్తం చెప్పండి"))
        self.assertFalse(is_panchangam_query("What should I wear today in Hyderabad?"))
        self.assertFalse(is_panchangam_query("What is the AQI right now?"))

    def test_five_limbs_sunrise_and_muhurtham_windows(self):
        p = self.svc.compute_panchangam(17.3850, 78.4867, date(2026, 11, 12))
        self.assertEqual(p["date"], "2026-11-12")
        self.assertEqual(p["timezone_label"], "IST")
        self.assertIn("Guruvara", p["vara"])
        self.assertEqual(p["masa"], "Kartika")
        self.assertIn("Shukla", p["tithi"]["name"])
        self.assertTrue(1 <= p["nakshatra"]["pada"] <= 4)
        self.assertIn("name", p["yoga"])
        self.assertTrue(len(p["karana"]) > 2)
        self.assertRegex(p["sunrise"], r"^\d{2}:\d{2}$")
        self.assertRegex(p["sunset"], r"^\d{2}:\d{2}$")
        self.assertIn("IST", p["muhurtham_windows"]["abhijit_muhurtham"])
        self.assertIn("IST", p["muhurtham_windows"]["rahu_kaal"])

    def test_lunisolar_festival_detection(self):
        diwali = self.svc.compute_panchangam(17.3850, 78.4867, date(2026, 11, 9))
        self.assertEqual(diwali["tithi"]["number"], 30)
        self.assertIn("Deepavali", diwali["special_event"] or "")

        kartik_purnima = self.svc.compute_panchangam(17.3850, 78.4867, date(2026, 11, 24))
        self.assertEqual(kartik_purnima["tithi"]["number"], 15)
        self.assertIn("Kartik Purnima", kartik_purnima["special_event"] or "")

    def test_hybrid_fusion_penalizes_thunderstorms(self):
        clear_weather = {
            "temperature": 27.0,
            "rain_chance": 5,
            "wind_speed": 8.0,
            "aqi": 55,
            "weather_code": 0,
        }
        storm_weather = {
            "temperature": 25.0,
            "rain_chance": 90,
            "wind_speed": 42.0,
            "aqi": 80,
            "weather_code": 95,
        }
        clear_fused = self.svc.fuse_panchangam_and_weather(
            17.3850,
            78.4867,
            weather_data=clear_weather,
            query="Best Muhurtham for outdoor wedding",
            date_str="2026-11-12",
        )
        storm_fused = self.svc.fuse_panchangam_and_weather(
            17.3850,
            78.4867,
            weather_data=storm_weather,
            query="Best Muhurtham for outdoor wedding",
            date_str="2026-11-12",
        )
        self.assertEqual(clear_fused["activity_focus"], "wedding")
        self.assertGreater(clear_fused["composite_score"], storm_fused["composite_score"] + 25)
        self.assertGreaterEqual(len(clear_fused["rag_knowledge"]), 1)

    def test_scan_upcoming_windows_ranks_best_day_first(self):
        daily = [
            {
                "date": "2026-11-12",
                "temp_max": 28.0,
                "rain_chance": 85,
                "wind_speed_max": 35.0,
                "weather_code": 95,
            },
            {
                "date": "2026-11-13",
                "temp_max": 27.5,
                "rain_chance": 5,
                "wind_speed_max": 8.0,
                "weather_code": 0,
            },
        ]
        ranked = self.svc.scan_upcoming_windows(
            17.3850, 78.4867, daily_forecast=daily, activity="wedding"
        )
        self.assertEqual(len(ranked), 2)
        self.assertEqual(ranked[0]["date"], "2026-11-13")
        self.assertGreater(ranked[0]["composite_score"], ranked[1]["composite_score"])


class TestPanchangamEndpoints(unittest.TestCase):
    def test_panchangam_weather_endpoint(self):
        from fastapi.testclient import TestClient
        from app.main import app

        mock_weather = {
            "location_name": "Hyderabad",
            "latitude": 17.385,
            "longitude": 78.4867,
            "temperature": 26.8,
            "apparent_temperature": 27.5,
            "condition": "Clear Sky",
            "weather_code": 0,
            "humidity": 55,
            "wind_speed": 9.0,
            "rain_chance": 5,
            "temp_max": 29,
            "temp_min": 18,
            "aqi": 70,
            "hourly": [],
        }
        mock_daily = [
            {
                "date": "2026-11-12",
                "weather_code": 0,
                "condition": "Clear Sky",
                "temp_max": 29.0,
                "temp_min": 18.0,
                "rain_chance": 5,
                "wind_speed_max": 9.0,
            },
            {
                "date": "2026-11-13",
                "weather_code": 1,
                "condition": "Partly Cloudy",
                "temp_max": 28.5,
                "temp_min": 18.5,
                "rain_chance": 10,
                "wind_speed_max": 10.0,
            },
        ]
        client = TestClient(app)
        with patch(
            "app.services.weather_service.weather_service.get_structured_weather_data",
            return_value=mock_weather,
        ), patch(
            "app.services.weather_service.weather_service.get_daily_forecast_list",
            return_value=mock_daily,
        ):
            res = client.get(
                "/api/weather/panchangam",
                params={
                    "lat": 17.385,
                    "lon": 78.4867,
                    "date": "2026-11-12",
                    "activity": "farming",
                    "days": 2,
                },
            )
        self.assertEqual(res.status_code, 200)
        body = res.json()
        pf = body["panchangam_fusion"]
        self.assertEqual(pf["activity_focus"], "farming")
        self.assertEqual(pf["masa"], "Kartika")
        self.assertEqual(len(pf["upcoming_windows"]), 2)

    def test_chat_completion_attaches_panchangam_fusion(self):
        from fastapi.testclient import TestClient
        from app.main import app

        mock_weather = {
            "location_name": "Hyderabad",
            "latitude": 17.385,
            "longitude": 78.4867,
            "temperature": 26.8,
            "apparent_temperature": 27.5,
            "condition": "Clear Sky",
            "weather_code": 0,
            "humidity": 55,
            "wind_speed": 9.0,
            "rain_chance": 5,
            "temp_max": 29,
            "temp_min": 18,
            "aqi": 70,
            "hourly": [],
        }

        class FakeAgent:
            async def get_response(self, user_message: str, session_id: str) -> str:
                return f"Received context with Panchangam: {'Panchangam + Weather Hybrid RAG' in user_message}"

        client = TestClient(app)
        with patch(
            "app.services.weather_service.weather_service.get_structured_weather_data",
            return_value=mock_weather,
        ), patch("app.services.ai_service.ai_agent", FakeAgent()):
            res = client.post(
                "/api/chat/completions",
                json={
                    "message": "Is today good for sowing crops per Tithi and Panchangam?",
                    "lat": 17.385,
                    "lon": 78.4867,
                    "session_id": "test_panchangam",
                },
            )
        self.assertEqual(res.status_code, 200)
        body = res.json()
        self.assertIn("Received context with Panchangam: True", body["reply"])
        self.assertIn("panchangam_fusion", body["weather_data"])
        self.assertEqual(body["weather_data"]["panchangam_fusion"]["activity_focus"], "farming")


if __name__ == "__main__":
    unittest.main()
