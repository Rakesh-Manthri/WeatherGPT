"""
WeatherGPT — Phase 4: Disaster Alerts & Geofenced Microclimate Endpoints
"""

import math
from typing import Any, Dict, List, Optional
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel
from ..services.alert_signing import alert_signing_service

router = APIRouter()


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculate the great-circle distance between two points in km."""
    r = 6371.0
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    )
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return r * c


# Active Seed Disaster Cells (Real Indian Microclimate Risk Zones)
SEED_RISK_CELLS = [
    {
        "alert_id": "WGPT-ALERT-CYC-2026-001",
        "severity": "CRITICAL",
        "hazard_type": "CYCLONE",
        "title": "Severe Cyclonic Storm Alert — Bay of Bengal Sector",
        "description": "Deep depression intensifying into a severe cyclonic storm with sustained winds of 90-110 km/h.",
        "lat": 17.6868,
        "lon": 83.2185,
        "radius_km": 120.0,
        "ttl_seconds": 14400,
        "safety_instructions": [
            "Coastal fishermen must stay ashore immediately.",
            "Board windows and prepare emergency rations.",
            "Follow SDRF / NDRF evacuation directives.",
        ],
    },
    {
        "alert_id": "WGPT-ALERT-FLD-2026-002",
        "severity": "WARNING",
        "hazard_type": "FLASH_FLOOD",
        "title": "Krishna Delta Flash Flood Advisory",
        "description": "Continuous heavy inflow causing sudden riverbank inundation in low-lying deltaic plains.",
        "lat": 16.5062,
        "lon": 80.6480,
        "radius_km": 45.0,
        "ttl_seconds": 10800,
        "safety_instructions": [
            "Move cattle and livestock to elevated ground.",
            "Avoid driving through submerged causeways.",
        ],
    },
    {
        "alert_id": "WGPT-ALERT-SQUALL-2026-003",
        "severity": "ADVISORY",
        "hazard_type": "SQUALL",
        "title": "Pre-Monsoon Squall & Lightning Warning — Deccan Ridge",
        "description": "Convective thunderstorm cells with sudden wind gusts up to 55 km/h and localized hail.",
        "lat": 17.3850,
        "lon": 78.4867,
        "radius_km": 35.0,
        "ttl_seconds": 7200,
        "safety_instructions": [
            "Do not take shelter under solitary trees or metal poles.",
            "Disconnect sensitive electronic farm equipment.",
        ],
    },
]


class VerifyAlertRequest(BaseModel):
    alert: Dict[str, Any]
    signature_hmac: Optional[str] = None
    signature_ecdsa: Optional[str] = None


@router.get("/public-key")
async def get_alert_authority_public_key():
    """Return the ECDSA P-256 Public Key for on-device alert signature verification."""
    return {
        "authority": "WeatherGPT Disaster Warning System",
        "curve": "NIST P-256 (secp256r1)",
        "hash_algorithm": "SHA-256",
        "public_key_pem": alert_signing_service.public_key_pem,
    }


@router.get("/risk-cells")
async def get_geofenced_risk_cells():
    """Return active microclimate hazard cells for background geofence tracking on mobile."""
    cells = []
    for seed in SEED_RISK_CELLS:
        signed = alert_signing_service.create_signed_alert(
            alert_id=seed["alert_id"],
            severity=seed["severity"],
            title=seed["title"],
            description=seed["description"],
            hazard_type=seed["hazard_type"],
            lat=seed["lat"],
            lon=seed["lon"],
            radius_km=seed["radius_km"],
            ttl_seconds=seed["ttl_seconds"],
            safety_instructions=seed["safety_instructions"],
        )
        cells.append(signed)
    return {"risk_cells": cells, "total_active": len(cells)}


@router.get("/active")
async def get_active_alerts(
    lat: Optional[float] = Query(None, description="User latitude"),
    lon: Optional[float] = Query(None, description="User longitude"),
    max_distance_km: float = Query(250.0, description="Search radius in km"),
):
    """
    Returns signed alerts. If user coordinates are supplied, calculates proximity
    and filters alerts within range, flagging 'is_within_geofence'.
    """
    alerts = []
    for seed in SEED_RISK_CELLS:
        signed = alert_signing_service.create_signed_alert(
            alert_id=seed["alert_id"],
            severity=seed["severity"],
            title=seed["title"],
            description=seed["description"],
            hazard_type=seed["hazard_type"],
            lat=seed["lat"],
            lon=seed["lon"],
            radius_km=seed["radius_km"],
            ttl_seconds=seed["ttl_seconds"],
            safety_instructions=seed["safety_instructions"],
        )

        if lat is not None and lon is not None:
            dist = haversine_km(lat, lon, seed["lat"], seed["lon"])
            signed["user_distance_km"] = round(dist, 1)
            signed["is_within_geofence"] = dist <= seed["radius_km"]

            if dist <= max_distance_km:
                alerts.append(signed)
        else:
            signed["user_distance_km"] = None
            signed["is_within_geofence"] = None
            alerts.append(signed)

    # Sort alerts by severity (CRITICAL first, then WARNING, ADVISORY)
    severity_order = {"CRITICAL": 0, "WARNING": 1, "ADVISORY": 2}
    alerts.sort(key=lambda a: severity_order.get(a["severity"], 99))
    return {"alerts": alerts, "count": len(alerts)}


@router.post("/verify")
async def verify_alert_signature(req: VerifyAlertRequest):
    """
    Verifies cryptographic signatures of an alert to confirm authenticity and detect tampering.
    """
    alert = dict(req.alert)
    hmac_sig = req.signature_hmac or alert.get("signature_hmac")
    ecdsa_sig = req.signature_ecdsa or alert.get("signature_ecdsa")

    if not hmac_sig and not ecdsa_sig:
        raise HTTPException(status_code=400, detail="Missing signature to verify.")

    hmac_valid = False
    ecdsa_valid = False

    if hmac_sig:
        hmac_valid = alert_signing_service.verify_alert_hmac(alert, hmac_sig)

    if ecdsa_sig:
        ecdsa_valid = alert_signing_service.verify_alert_ecdsa(alert, ecdsa_sig)

    is_verified = (hmac_sig is None or hmac_valid) and (ecdsa_sig is None or ecdsa_valid)

    return {
        "verified": is_verified,
        "hmac_valid": hmac_valid,
        "ecdsa_valid": ecdsa_valid,
        "alert_id": alert.get("alert_id"),
        "severity": alert.get("severity"),
    }
