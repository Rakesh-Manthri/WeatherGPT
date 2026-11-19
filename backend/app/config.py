import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

_backend_env = Path(__file__).resolve().parent.parent / ".env"

class Settings(BaseSettings):
    SUPABASE_URL: str = ""
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_KEY: str = ""
    WEATHERNEXT_API_KEY: str = ""
    WEATHERNEXT_MODE: str = "simulation"  # "simulation" (Primary 64-member DeepMind Ensemble), "auto", or "live"
    GEMINI_API_KEY: str = ""
    GOOGLE_SERVICE_ACCOUNT_FILE: str = "service_account.json"
    GOOGLE_CLOUD_PROJECT: str = "weathergpt-509714"
    PORT: int = 8000
    ENVIRONMENT: str = "production"
    CORS_ORIGINS: str = "*"
    NEWS_API_KEY: str = ""
    GNEWS_API_KEY: str = ""

    model_config = SettingsConfigDict(
        env_file=(str(_backend_env), ".env", "backend/.env", "../.env"), 
        env_file_encoding="utf-8", 
        extra="ignore"
    )

settings = Settings()
