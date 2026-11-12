"""
Unit & API tests for F2.2 End-to-End Vernacular Voice Pipeline.
Run: backend\\venv\\Scripts\\python -m unittest backend\\tests\\test_indic_voice.py -v
"""

import os
import sys
import unittest
from unittest.mock import AsyncMock, patch

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from app.services.indic_voice_service import (
    INDIC_LANGUAGE_SPECS,
    IndicVoiceService,
)


class TestIndicVoiceService(unittest.TestCase):
    def setUp(self):
        self.svc = IndicVoiceService()

    def test_all_seven_target_languages_registered(self):
        expected_codes = {"en_IN", "hi", "te", "ta", "kn", "bn", "mr"}
        self.assertEqual(set(INDIC_LANGUAGE_SPECS.keys()), expected_codes)

    def test_explicit_language_resolution_including_marathi(self):
        for alias, expected in [
            ("Telugu", "te"),
            ("te_IN", "te"),
            ("हिन्दी", "hi"),
            ("Marathi", "mr"),
            ("mr-IN", "mr"),
            ("Tamil", "ta"),
            ("Kannada", "kn"),
            ("Bangla", "bn"),
            ("English", "en_IN"),
        ]:
            spec = self.svc.resolve_language(alias, "What is the weather?")
            self.assertEqual(spec.code, expected, f"Failed for alias {alias}")

    def test_unicode_script_autodetection_and_marathi_disambiguation(self):
        # Spoken Telugu overrides default English UI
        te_spec = self.svc.resolve_language("English", "ఈ రోజు వర్షం పడుతుందా?")
        self.assertEqual(te_spec.code, "te")
        self.assertEqual(te_spec.tts_locale, "te-IN")

        # Spoken Tamil
        self.assertEqual(
            self.svc.resolve_language("English", "இன்று மழை பெய்யுமா?").code, "ta"
        )
        # Spoken Kannada
        self.assertEqual(
            self.svc.resolve_language("English", "ಇಂದು ಮಳೆ ಬರುತ್ತದೆಯೇ?").code, "kn"
        )
        # Spoken Bengali
        self.assertEqual(
            self.svc.resolve_language("English", "আজ কি বৃষ্টি হবে?").code, "bn"
        )
        # Devanagari Hindi vs Marathi
        self.assertEqual(
            self.svc.resolve_language("English", "आज बारिश होगी क्या?").code, "hi"
        )
        self.assertEqual(
            self.svc.resolve_language("English", "आज पाऊस पडेल का? पेरणी करावी का?").code,
            "mr",
        )

    def test_prompt_directive_and_voice_mode(self):
        te_spec = INDIC_LANGUAGE_SPECS["te"]
        directive = self.svc.build_prompt_directive(te_spec, voice_mode=True)
        self.assertIn("Telugu", directive)
        self.assertIn("మాగాణి వర్షం", directive)
        self.assertIn("Voice Assistant Mode", directive)

    def test_tts_sanitization_strips_markdown_emojis_and_expands_units(self):
        raw_hi = (
            "### आज का मौसम 🌦️\n"
            "- तापमान **31°C** और हवा `14 km/h` रहेगी।\n"
            "- उमस **72%** है & [रडार देखें](https://example.com) 🧥"
        )
        cleaned = self.svc.sanitize_for_tts(raw_hi, INDIC_LANGUAGE_SPECS["hi"])
        self.assertNotIn("#", cleaned)
        self.assertNotIn("**", cleaned)
        self.assertNotIn("`", cleaned)
        self.assertNotIn("http", cleaned)
        self.assertNotIn("🌦", cleaned)
        self.assertNotIn("🧥", cleaned)
        self.assertIn("डिग्री सेल्सियस", cleaned)
        self.assertIn("किलोमीटर प्रति घंटा", cleaned)
        self.assertIn("प्रतिशत", cleaned)
        self.assertIn("रडार देखें", cleaned)

        raw_mr = "आज कमाल तापमान 29°C आणि आर्द्रता 65% आहे."
        cleaned_mr = self.svc.sanitize_for_tts(raw_mr, INDIC_LANGUAGE_SPECS["mr"])
        self.assertIn("अंश सेल्सिअस", cleaned_mr)
        self.assertIn("टक्के", cleaned_mr)
        self.assertTrue(cleaned_mr.endswith((".", "।")))


class TestIndicVoiceApiEndpoints(unittest.TestCase):
    def test_languages_endpoint_lists_seven_languages(self):
        from fastapi.testclient import TestClient
        from app.main import app

        resp = TestClient(app).get("/api/chat/languages")
        self.assertEqual(resp.status_code, 200)
        langs = resp.json()["languages"]
        codes = {item["code"] for item in langs}
        self.assertEqual(codes, {"en_IN", "hi", "te", "ta", "kn", "bn", "mr"})
        for item in langs:
            self.assertIn("stt_locale", item)
            self.assertIn("tts_locale", item)
            self.assertTrue(len(item["sample_queries"]) >= 2)

    def test_chat_completions_voice_mode_returns_vernacular_tts_payload(self):
        from fastapi.testclient import TestClient
        from app.main import app

        mock_agent = unittest.mock.MagicMock()
        mock_agent.get_response = AsyncMock(
            return_value="**ఈ రోజు** వాతావరణం 30°C, గాలి 12 km/h & తేమ 68% ఉంటుంది 🌤️."
        )

        with patch("app.routers.chat.ai_service.ai_agent", mock_agent), patch(
            "app.routers.chat.weather_service.get_structured_weather_data",
            return_value={
                "location_name": "Hyderabad",
                "latitude": 17.385,
                "longitude": 78.4867,
                "temperature": 30.0,
                "condition": "Partly Cloudy",
                "temp_max": 32,
                "temp_min": 22,
                "humidity": 68,
                "wind_speed": 12.0,
                "rain_chance": 10,
                "aqi": 72,
            },
        ):
            resp = TestClient(app).post(
                "/api/chat/completions",
                json={
                    "message": "ఈ రోజు వాతావరణం ఎలా ఉంది?",
                    "lat": 17.385,
                    "lon": 78.4867,
                    "language": "English",
                    "voice_mode": True,
                },
            )

        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["detected_language"], "Telugu")
        self.assertEqual(data["tts_locale"], "te-IN")
        self.assertEqual(data["stt_locale"], "te_IN")
        self.assertTrue(data["weather_context_used"])
        self.assertIn("డిగ్రీల సెల్సియస్", data["tts_text"])
        self.assertNotIn("**", data["tts_text"])

        sent_prompt = mock_agent.get_response.call_args.kwargs["user_message"]
        self.assertIn("Telugu", sent_prompt)
        self.assertIn("Voice Assistant Mode", sent_prompt)


if __name__ == "__main__":
    unittest.main()
