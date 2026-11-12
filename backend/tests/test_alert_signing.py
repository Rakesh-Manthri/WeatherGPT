"""
WeatherGPT — Phase 4.2 & 4.1 Cryptographic Alert Signing & Geofence Unit Tests
"""

import unittest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.services.alert_signing import alert_signing_service, AlertSigningService


class TestAlertSigningAndGeofence(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        self.signer = AlertSigningService()

    def test_ecdsa_and_hmac_signatures_verify_cleanly(self):
        alert = self.signer.create_signed_alert(
            alert_id="TEST-ALERT-001",
            severity="CRITICAL",
            title="Severe Cyclone Advisory",
            description="High wind alert along coastal Andhra.",
            hazard_type="CYCLONE",
            lat=17.6868,
            lon=83.2185,
            radius_km=100.0,
        )

        self.assertIn("signature_hmac", alert)
        self.assertIn("signature_ecdsa", alert)

        # Verify HMAC
        hmac_ok = self.signer.verify_alert_hmac(alert, alert["signature_hmac"])
        self.assertTrue(hmac_ok)

        # Verify ECDSA
        ecdsa_ok = self.signer.verify_alert_ecdsa(alert, alert["signature_ecdsa"])
        self.assertTrue(ecdsa_ok)

    def test_tampered_alert_fails_verification(self):
        alert = self.signer.create_signed_alert(
            alert_id="TEST-ALERT-002",
            severity="WARNING",
            title="Flash Flood Advisory",
            description="River levels rising.",
            hazard_type="FLASH_FLOOD",
            lat=16.5062,
            lon=80.6480,
            radius_km=50.0,
        )

        tampered_alert = dict(alert)
        # Malicious actor changes severity to CRITICAL or alters title
        tampered_alert["severity"] = "CRITICAL"

        hmac_ok = self.signer.verify_alert_hmac(tampered_alert, alert["signature_hmac"])
        self.assertFalse(hmac_ok)

        ecdsa_ok = self.signer.verify_alert_ecdsa(tampered_alert, alert["signature_ecdsa"])
        self.assertFalse(ecdsa_ok)

    def test_public_key_endpoint_returns_valid_pem(self):
        res = self.client.get("/api/alerts/public-key")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("BEGIN PUBLIC KEY", data["public_key_pem"])
        self.assertEqual(data["curve"], "NIST P-256 (secp256r1)")

    def test_risk_cells_endpoint_returns_signed_cells(self):
        res = self.client.get("/api/alerts/risk-cells")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertGreaterEqual(data["total_active"], 3)
        first_cell = data["risk_cells"][0]
        self.assertIn("geofence", first_cell)
        self.assertIn("signature_hmac", first_cell)
        self.assertIn("signature_ecdsa", first_cell)

    def test_active_alerts_geofence_calculation(self):
        # Coordinates very close to Visakhapatnam (17.6868, 83.2185)
        res = self.client.get("/api/alerts/active?lat=17.7000&lon=83.2200")
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertGreater(data["count"], 0)

        cyc = next((a for a in data["alerts"] if a["hazard_type"] == "CYCLONE"), None)
        self.assertIsNotNone(cyc)
        self.assertLess(cyc["user_distance_km"], 10.0)
        self.assertTrue(cyc["is_within_geofence"])

    def test_verify_endpoint_validates_alert_payload(self):
        alert = alert_signing_service.create_signed_alert(
            alert_id="VERIFY-TEST-001",
            severity="ADVISORY",
            title="Squall Alert",
            description="Wind gusts expected.",
            hazard_type="SQUALL",
            lat=17.3850,
            lon=78.4867,
            radius_km=30.0,
        )

        res = self.client.post("/api/alerts/verify", json={"alert": alert})
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data["verified"])
        self.assertTrue(data["hmac_valid"])
        self.assertTrue(data["ecdsa_valid"])


if __name__ == "__main__":
    unittest.main()
