"""
Test WeatherNext 3 access using GOOGLE_APPLICATION_CREDENTIALS ADC approach.
This matches what the reference notebook does (auth.authenticate_user() sets ADC).
"""
import os, sys
sys.path.insert(0, "backend")

# Set ADC to our service account key BEFORE importing obstore
KEY_PATH = os.path.abspath("backend/service_account.json")
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = KEY_PATH
print("ADC set to:", KEY_PATH)

import obstore.store, zarr, xarray as xr, numpy as np
from datetime import datetime, timezone, timedelta

PROJECT_ID = "weathergpt-509714"

# Latest 6-hourly init
now = datetime.now(timezone.utc)
init_hour = (now.hour // 6) * 6
init_dt = now.replace(hour=init_hour, minute=0, second=0, microsecond=0) - timedelta(hours=6)
date_str = init_dt.strftime("%Y%m%d")
hour_str = f"{init_dt.hour:02d}hr"
prefix = f"weathernext_3_0_0/zarr/2026_to_present/{date_str}_{hour_str}_01_preds/predictions.zarr"
print("Opening prefix:", prefix)

# Exactly as in the reference notebook — let obstore pick up ADC
gcs_store = obstore.store.GCSStore(
    bucket="weathernext3_spatial",
    prefix=prefix,
    client_options={"default_headers": {"x-goog-user-project": PROJECT_ID}},
)
zstore = zarr.storage.ObjectStore(gcs_store)
ds = xr.open_zarr(zstore, chunks={})
print("Dataset opened!")
print("Variables:", list(ds.data_vars)[:5])

# Hyderabad
lat, lon = 17.385, 78.4867
lat_idx = int(np.argmin(np.abs(ds.lat_0p1.values - lat)))
lon_idx = int(np.argmin(np.abs(ds.lon_0p1.values - lon)))
subset = ds.isel(lat_0p1=lat_idx, lon_0p1=lon_idx, lead_time=0, lead_subtime=0).compute()
temp_k = float(subset["temperature_2m"].mean("sample").values)
print(f"Hyderabad temperature: {round(temp_k - 273.15, 1)} C")
