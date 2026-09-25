-- 001_weather_cache.sql
-- Create weather_cache table with PostGIS geometry

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TYPE data_source AS ENUM ('weathernext', 'openmeteo');

CREATE TABLE IF NOT EXISTS public.weather_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location GEOGRAPHY(POINT) NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lon DOUBLE PRECISION NOT NULL,
    data JSONB NOT NULL,
    source data_source NOT NULL,
    fetched_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Index for fast proximity searches
CREATE INDEX IF NOT EXISTS weather_cache_location_idx ON public.weather_cache USING GIST (location);

-- RLS
ALTER TABLE public.weather_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read access for all users" ON public.weather_cache FOR SELECT USING (true);
-- Only service role can insert/update
