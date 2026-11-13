import os
import logging
from pathlib import Path
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, Optional

logger = logging.getLogger(__name__)


class WeatherNextService:
    """
    Fetches WeatherNext 3 ensemble forecasts from Google DeepMind's operational
    weather model stored as Zarr on Google Cloud Storage.

    Bucket   : weathernext3_spatial  (Requester Pays — billed to weathergpt-509714)
    Path     : weathernext_3_0_0/zarr/2026_to_present/<YYYYMMDD_HHhr_XX_preds>/predictions.zarr/
    Grid     : 0.1° global (lat: –90→90, lon: 0→359.9)
    Ensemble : 64 members (sample dimension)
    """

    BUCKET = "weathernext3_spatial"
    PREFIX_BASE = "weathernext_3_0_0/zarr/2026_to_present"
    PROJECT_ID = "weathergpt-509714"

    def __init__(self):
        self.is_initialized = False
        self._credentials = None
        self._init_credentials()

    # ------------------------------------------------------------------
    # Auth
    # ------------------------------------------------------------------

    def _init_credentials(self):
        try:
            import google.auth
            from google.oauth2 import service_account
            from ..config import settings

            key_path = settings.GOOGLE_SERVICE_ACCOUNT_FILE
            if not os.path.isabs(key_path):
                # Resolve relative path from the backend root
                base_dir = Path(__file__).resolve().parent.parent.parent
                candidate = base_dir / key_path
                if candidate.exists():
                    key_path = str(candidate)

            self._project_id = settings.GOOGLE_CLOUD_PROJECT or self.PROJECT_ID
            scopes = ["https://www.googleapis.com/auth/cloud-platform"]

            if os.path.isfile(key_path):
                self._credentials = service_account.Credentials.from_service_account_file(
                    key_path,
                    scopes=scopes,
                )
                # obstore's GCS store discovers credentials via ADC.
                os.environ.setdefault("GOOGLE_APPLICATION_CREDENTIALS", key_path)
                logger.info("WeatherNext 3: service account credentials loaded.")
            else:
                self._credentials, _ = google.auth.default(scopes=scopes)
                logger.info("WeatherNext 3: application default credentials loaded.")

            self.is_initialized = True
        except Exception as exc:
            logger.warning(f"WeatherNext 3: credential initialisation failed — {exc}")

    def _get_access_token(self) -> str:
        from google.auth.transport.requests import Request

        if not self._credentials.valid:
            self._credentials.refresh(Request())
        return self._credentials.token

    # ------------------------------------------------------------------
    # Path helpers
    # ------------------------------------------------------------------

    def _get_latest_init_path(self) -> str:
        """
        Return the GCS Zarr prefix for the most recent 6-hourly run
        (init hours: 00, 06, 12, 18 UTC). We step back one full 6-h cycle
        to allow for data publication latency.
        """
        now = datetime.now(timezone.utc)
        init_hour = (now.hour // 6) * 6
        init_dt = now.replace(hour=init_hour, minute=0, second=0, microsecond=0)
        init_dt -= timedelta(hours=6)  # one cycle back for guaranteed availability

        date_str = init_dt.strftime("%Y%m%d")
        hour_str = f"{init_dt.hour:02d}hr"
        # Member 01 is the first full-ensemble (360 h) member
        return f"{self.PREFIX_BASE}/{date_str}_{hour_str}_01_preds/predictions.zarr"

    # ------------------------------------------------------------------
    # Core data fetch
    # ------------------------------------------------------------------

    def get_forecast(self, lat: float, lon: float) -> Dict[str, Any]:
        """
        Query WeatherNext 3 Zarr store for a single lat/lon point.
        Returns a dict with weather variables at the first forecast step (~6 h out).
        """
        if not -90 <= lat <= 90 or not -180 <= lon <= 180:
            return {
                "source": "WeatherNext 3",
                "status": "error",
                "error": "latitude must be between -90 and 90 and longitude between -180 and 180",
            }
        if not self.is_initialized:
            return {"source": "WeatherNext 3", "status": "standby", "error": "credentials not loaded"}

        try:
            import numpy as np
            import zarr
            import obstore
            import obstore.store
            import xarray as xr

            prefix = self._get_latest_init_path()

            # Reference notebook pattern: let obstore auto-discover ADC credentials
            # (GOOGLE_APPLICATION_CREDENTIALS env var set in _init_credentials)
            # Only the Requester-Pays billing header is needed explicitly.
            gcs_store = obstore.store.GCSStore(
                bucket=self.BUCKET,
                prefix=prefix,
                client_options={
                    "default_headers": {"x-goog-user-project": self._project_id},
                    "timeout": "2s",
                },
                retry_config={"max_retries": 1},
            )

            zstore = zarr.storage.ObjectStore(gcs_store)
            ds = xr.open_zarr(zstore, chunks={})

            # WeatherNext uses 0–360 longitude range
            lon_360 = lon if lon >= 0 else lon + 360.0

            # Nearest-neighbour grid indices
            lat_idx = int(np.argmin(np.abs(ds.lat_0p1.values - lat)))
            lon_idx = int(np.argmin(np.abs(ds.lon_0p1.values - lon_360)))

            # First valid forecast step (lead_time=0, lead_subtime=0 → ~6 h forecast)
            subset = ds.isel(
                lat_0p1=lat_idx,
                lon_0p1=lon_idx,
                lead_time=0,
                lead_subtime=0,
            ).compute()  # pull data into memory

            def ens_mean(var: str) -> float:
                return float(subset[var].mean("sample").values)

            temp_k = ens_mean("temperature_2m")
            dewpoint_k = ens_mean("dewpoint_temperature_2m")
            u_wind = ens_mean("u_component_of_wind_10m")
            v_wind = ens_mean("v_component_of_wind_10m")
            precip_m = ens_mean("total_precipitation_1hr")
            cloud_total = ens_mean("total_cloud_cover")
            pressure_pa = ens_mean("mean_sea_level_pressure")

            wind_speed_kmh = round((u_wind**2 + v_wind**2) ** 0.5 * 3.6, 1)

            # Ensemble spread (std) on temperature as a forecast confidence indicator
            temp_spread = float(subset["temperature_2m"].std("sample").values)

            return {
                "source": "WeatherNext 3 (Google DeepMind / GCS Zarr)",
                "status": "live",
                "forecast_init": prefix.split("/")[-2],
                "grid_resolution_deg": 0.1,
                "temperature_2m_c": round(temp_k - 273.15, 1),
                "dewpoint_2m_c": round(dewpoint_k - 273.15, 1),
                "wind_speed_kmh": wind_speed_kmh,
                "wind_u_ms": round(u_wind, 2),
                "wind_v_ms": round(v_wind, 2),
                "precipitation_1hr_mm": round(precip_m * 1000, 2),
                "total_cloud_cover_fraction": round(cloud_total, 2),
                "mean_sea_level_pressure_hpa": round(pressure_pa / 100, 1),
                "ensemble_members": 64,
                "temperature_ensemble_spread_c": round(temp_spread, 2),
            }

        except Exception as exc:
            logger.warning(f"WeatherNext 3 forecast query failed: {exc}")
            return {"source": "WeatherNext 3", "status": "fallback", "error": str(exc)}

    # ------------------------------------------------------------------
    # AI-facing summary
    # ------------------------------------------------------------------

    def get_forecast_summary_for_ai(self, lat: float, lon: float) -> str:
        """
        Return a concise, human-readable summary of WeatherNext 3 data for
        injection into the Gemini AI context window.
        """
        data = self.get_forecast(lat, lon)

        if data.get("status") == "live":
            spread_note = (
                f" (Ensemble spread ±{data['temperature_ensemble_spread_c']}°C — "
                + ("low uncertainty" if data["temperature_ensemble_spread_c"] < 1.0 else "moderate uncertainty")
                + ")"
            )
            return (
                f"WeatherNext 3 Ensemble Forecast [Google DeepMind, 0.1° res, "
                f"64-member ensemble, init: {data['forecast_init']}]: "
                f"Temperature: {data['temperature_2m_c']}°C{spread_note}, "
                f"Dew Point: {data['dewpoint_2m_c']}°C, "
                f"Wind Speed: {data['wind_speed_kmh']} km/h, "
                f"Precipitation (1hr): {data['precipitation_1hr_mm']} mm, "
                f"Cloud Cover: {round(data['total_cloud_cover_fraction'] * 100)}%, "
                f"MSLP: {data['mean_sea_level_pressure_hpa']} hPa."
            )

        return (
            "WeatherNext 3 ensemble forecast telemetry is currently in standby mode. "
            "Standard Open-Meteo and Earth Engine data sources are active."
        )


# Module-level singleton — imported by weather_service and ai_service
weathernext_service = WeatherNextService()
