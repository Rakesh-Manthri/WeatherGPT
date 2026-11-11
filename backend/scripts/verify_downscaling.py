"""
Live integration check for F1.2 Spatial Downscaling Engine across diverse topographies.
Run: backend\\venv\\Scripts\\python backend\\scripts\\verify_downscaling.py
"""

import os
import sys
import time

BACKEND_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

from app.services.earth_engine_service import earth_engine_service
from app.services.weather_service import weather_service

LOCATIONS = [
    ("Shimla Ridge", 31.1048, 77.1734),
    ("Hyderabad Abids", 17.3850, 78.4867),
    ("Mumbai Marine Drive", 18.9432, 72.8235),
    ("Ooty Doddabetta", 11.4008, 76.7358),
    ("Oslo Norway", 59.9139, 10.7522),
]


def main():
    print(f"Earth Engine initialized: {earth_engine_service.is_initialized}")
    for name, lat, lon in LOCATIONS:
        t0 = time.time()
        data = weather_service.get_structured_weather_data(lat, lon, name)
        dt = time.time() - t0
        ds = data.get("spatial_downscaling") or {}
        tp = ds.get("terrain_profile") or {}
        adj = ds.get("adjustments") or {}
        era5 = ds.get("coarse_model_downscaling", {}).get("era5_land")

        print(f"\n=== {name} ({dt:.2f}s) ===")
        print(f"  Status: {ds.get('status')} | Zone: {ds.get('microclimate_zone')} | DEM: {tp.get('dem_dataset')}")
        print(
            f"  Elev: local={tp.get('local_elevation_m')}m, "
            f"coarse25km={tp.get('coarse_grid_elevation_m')}m, "
            f"ref={tp.get('model_reference_elevation_m')}m, slope={tp.get('slope_deg')}deg"
        )
        print(
            f"  LandCover: urban={tp.get('built_up_pct')}%, "
            f"tree={tp.get('tree_cover_pct')}%, "
            f"veg={tp.get('vegetation_pct')}%, "
            f"water10km={tp.get('water_10km_pct')}%"
        )
        print(
            f"  Temp: raw={ds.get('raw_temperature_c')}C -> "
            f"downscaled={ds.get('downscaled_temperature_c')}C "
            f"(net={ds.get('net_temperature_delta_c')}C)"
        )
        print(f"  Adjustments: {adj}")
        print(
            f"  WindMult={ds.get('wind_terrain_multiplier')}x -> {data.get('wind_speed')} km/h | "
            f"Pressure={data.get('pressure')} hPa | RH={data.get('humidity')}%"
        )
        if era5:
            print(f"  ERA5-Land Coarse->1km: {era5}")

    t_cache = time.time()
    p_cached = earth_engine_service.get_microclimate_terrain_profile(17.3850, 78.4867)
    print(
        f"\nTerrain cache hit latency: {(time.time() - t_cache) * 1000:.3f} ms "
        f"(cached={p_cached.get('cached')})"
    )


if __name__ == "__main__":
    main()
