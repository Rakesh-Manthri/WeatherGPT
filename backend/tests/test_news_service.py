"""
WeatherGPT — Phase 5.2 Real-Time Weather News Engine Unit Tests
"""

import unittest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.services.news_service import weather_news_service, WeatherNewsService


class TestWeatherNewsEngine(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)

    def test_news_retrieval_and_semantic_deduplication(self):
        items = weather_news_service.get_weather_news(limit=10)
        self.assertGreater(len(items), 0)

        # Check deduplication: raw stream has a duplicate cyclone item
        titles = [i["title"] for i in items]
        cyclone_articles = [t for t in titles if "Bay" in t and "Cyclone" in t]
        # Only 1 deduplicated cyclone article should exist
        self.assertEqual(len(cyclone_articles), 1)

        # Verify merged citations
        cyc_item = next(i for i in items if "Bay" in i["title"] and "Cyclone" in i["title"])
        self.assertIn("Regional Bureau Wire", cyc_item["citations"])
        self.assertIn("IMD National Bulletin No. 14", cyc_item["citations"])

    def test_category_filtering(self):
        agri_items = weather_news_service.get_weather_news(category="AGRICULTURE")
        self.assertGreater(len(agri_items), 0)
        for item in agri_items:
            self.assertEqual(item["category"], "AGRICULTURE")

        alert_items = weather_news_service.get_weather_news(category="ALERTS")
        self.assertGreater(len(alert_items), 0)
        for item in alert_items:
            self.assertEqual(item["category"], "ALERTS")

    def test_jaccard_similarity_calculation(self):
        t1 = "IMD Issues Cyclone Alert for Coastal Andhra"
        t2 = "Depression in Bay: Cyclone Alert for Coastal Andhra Coast"
        sim = WeatherNewsService.calculate_similarity(t1, t2)
        self.assertGreater(sim, 0.40)

        t3 = "Krishi Vigyan Kendra Issues Sowing Advisory for Kharif"
        sim_diff = WeatherNewsService.calculate_similarity(t1, t3)
        self.assertLess(sim_diff, 0.15)

    def test_news_api_endpoint(self):
        res = self.client.get("/api/news/weather?category=ALL&limit=5")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("articles", data)
        self.assertGreater(data["total"], 0)
        first = data["articles"][0]
        self.assertIn("title", first)
        self.assertIn("source", first)
        self.assertIn("citations", first)

    def test_news_categories_endpoint(self):
        res = self.client.get("/api/news/categories")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("categories", data)
        cat_ids = [c["id"] for c in data["categories"]]
        self.assertIn("ALL", cat_ids)
        self.assertIn("AGRICULTURE", cat_ids)
        self.assertIn("CYCLONE", cat_ids)


if __name__ == "__main__":
    unittest.main()
