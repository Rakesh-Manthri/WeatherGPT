"""
WeatherGPT — Phase 5.2: Weather News Feed Endpoints
"""

from typing import Optional
from fastapi import APIRouter, Query
from ..services.news_service import weather_news_service

router = APIRouter()


@router.get("/weather")
async def get_weather_news_feed(
    category: Optional[str] = Query(None, description="Category filter (e.g. ALL, ALERTS, AGRICULTURE, MONSOON, CLIMATE, CYCLONE)"),
    limit: int = Query(10, ge=1, le=50, description="Max news articles to return"),
):
    """
    Returns AI-curated, semantically deduplicated meteorological news
    with verifiable citations from IMD, NDMA, and agricultural research institutes.
    """
    items = weather_news_service.get_weather_news(category=category, limit=limit)
    return {
        "category": category or "ALL",
        "total": len(items),
        "articles": items,
    }


@router.get("/categories")
async def get_news_categories():
    """Returns available news categories and metadata."""
    return {
        "categories": [
            {"id": "ALL", "label": "All Updates", "icon": "newspaper"},
            {"id": "ALERTS", "label": "Disaster Alerts", "icon": "warning"},
            {"id": "AGRICULTURE", "label": "Krishi & Sowing", "icon": "eco"},
            {"id": "CYCLONE", "label": "Cyclones & Storms", "icon": "cyclone"},
            {"id": "MONSOON", "label": "Monsoon Watch", "icon": "water_drop"},
            {"id": "CLIMATE", "label": "Microclimate & UHI", "icon": "thermostat"},
        ]
    }
