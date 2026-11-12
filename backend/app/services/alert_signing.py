"""
WeatherGPT — Phase 4.2: Cryptographic Alert Signing Service
Signs severe disaster warnings and microclimate risk cells using ECDSA (NIST P-256)
and HMAC-SHA256 to guarantee alert authenticity and prevent malicious alert spoofing.
"""

import base64
import hashlib
import hmac
import json
import os
import time
from typing import Any, Dict, List, Optional, Tuple
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization


class AlertSigningService:
    """
    Cryptographic Alert Authority for WeatherGPT.
    Signs severe disaster alerts and provides signature verification for mobile clients.
    """

    DEFAULT_SHARED_SECRET = "WeatherGPT-Disaster-Alert-Authority-Key-2026-NIST-P256"

    def __init__(self, private_key_pem: Optional[str] = None, shared_secret: Optional[str] = None):
        self.shared_secret = (
            shared_secret or os.getenv("WEATHERGPT_ALERT_SECRET", self.DEFAULT_SHARED_SECRET)
        ).encode("utf-8")

        # Generate or load ECDSA P-256 Keypair
        if private_key_pem:
            self._private_key = serialization.load_pem_private_key(
                private_key_pem.encode("utf-8"), password=None
            )
        else:
            self._private_key = ec.generate_private_key(ec.SECP256R1())

        self._public_key = self._private_key.public_key()
        self._public_key_pem = self._public_key.public_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PublicFormat.SubjectPublicKeyInfo,
        ).decode("utf-8")

    @property
    def public_key_pem(self) -> str:
        return self._public_key_pem

    IGNORE_KEYS = {
        "signature",
        "signature_type",
        "signature_hmac",
        "signature_ecdsa",
        "algorithm",
        "verified",
        "user_distance_km",
        "is_within_geofence",
    }

    @classmethod
    def canonical_serialize(cls, payload: Dict[str, Any]) -> bytes:
        """Deterministically sort keys and strip variable metadata for canonical signature hashing."""
        clean = {k: v for k, v in payload.items() if k not in cls.IGNORE_KEYS}
        return json.dumps(clean, sort_keys=True, separators=(",", ":")).encode("utf-8")

    def sign_alert_hmac(self, payload: Dict[str, Any]) -> str:
        """Create an HMAC-SHA256 signature (compact hex string)."""
        data = self.canonical_serialize(payload)
        sig = hmac.new(self.shared_secret, data, hashlib.sha256).hexdigest()
        return sig

    def verify_alert_hmac(self, payload: Dict[str, Any], signature: str) -> bool:
        """Verify HMAC-SHA256 signature in constant time."""
        expected = self.sign_alert_hmac(payload)
        return hmac.compare_digest(expected, signature)

    def sign_alert_ecdsa(self, payload: Dict[str, Any]) -> str:
        """Create an ECDSA P-256 SHA-256 signature (Base64 string)."""
        data = self.canonical_serialize(payload)
        raw_sig = self._private_key.sign(data, ec.ECDSA(hashes.SHA256()))
        return base64.b64encode(raw_sig).decode("utf-8")

    def verify_alert_ecdsa(self, payload: Dict[str, Any], signature_b64: str) -> bool:
        """Verify ECDSA signature with the public key."""
        try:
            data = self.canonical_serialize(payload)
            raw_sig = base64.b64decode(signature_b64)
            self._public_key.verify(raw_sig, data, ec.ECDSA(hashes.SHA256()))
            return True
        except Exception:
            return False

    def create_signed_alert(
        self,
        alert_id: str,
        severity: str,
        title: str,
        description: str,
        hazard_type: str,
        lat: float,
        lon: float,
        radius_km: float,
        ttl_seconds: int = 7200,
        safety_instructions: Optional[List[str]] = None,
    ) -> Dict[str, Any]:
        """
        Creates a tamper-proof disaster alert object signed with both HMAC and ECDSA.
        """
        now = int(time.time())
        alert = {
            "alert_id": alert_id,
            "authority": "WeatherGPT Disaster Warning System",
            "severity": severity.upper(),  # CRITICAL, WARNING, ADVISORY
            "hazard_type": hazard_type,  # CYCLONE, FLASH_FLOOD, SQUALL, HEATWAVE
            "title": title,
            "description": description,
            "geofence": {
                "latitude": round(lat, 4),
                "longitude": round(lon, 4),
                "radius_km": round(radius_km, 1),
            },
            "issued_at": now,
            "expires_at": now + ttl_seconds,
            "safety_instructions": safety_instructions or [
                "Stay indoors away from windows.",
                "Keep emergency battery pack and potable water ready.",
            ],
        }

        # Attach cryptographic signatures
        alert["signature_hmac"] = self.sign_alert_hmac(alert)
        alert["signature_ecdsa"] = self.sign_alert_ecdsa(alert)
        alert["algorithm"] = "HMAC-SHA256+ECDSA-P256"
        return alert


alert_signing_service = AlertSigningService()
