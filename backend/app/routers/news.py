"""
WeatherGPT — Phase 5.2 / F9-11: Multi-Source Weather News Feed Endpoints
"""

from typing import Optional
from fastapi import APIRouter, Query
from ..services.news_service import weather_news_service

router = APIRouter()


@router.get("/weather")
async def get_weather_news_feed(
    category: Optional[str] = Query(None, description="Category filter (e.g. ALL, ALERTS, AGRICULTURE, MONSOON, CLIMATE, CYCLONE)"),
    source: Optional[str] = Query(None, description="Source type filter (e.g. ALL, GOVERNMENT, GLOBAL, SCIENCE)"),
    limit: int = Query(15, ge=1, le=50, description="Max news articles to return"),
):
    """
    Returns AI-curated, semantically deduplicated meteorological news
    aggregated across Government authorities (IMD, NDMA), Global wires (BBC, Reuters, AP, TOI),
    and Climate/Agro Science institutes (ICAR, ISRO, ECMWF).
    """
    items = weather_news_service.get_weather_news(
        category=category,
        source_type=source,
        limit=limit,
    )
    return {
        "category": (category or "ALL").upper(),
        "source": (source or "ALL").upper(),
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


@router.get("/sources")
async def get_news_sources():
    """
    Returns the roster of active multi-source meteorological, media,
    and research news sources.
    """
    sources = weather_news_service.get_news_sources()
    return {
        "total": len(sources),
        "sources": sources,
    }
