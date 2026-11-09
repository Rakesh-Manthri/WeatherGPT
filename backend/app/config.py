from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    SUPABASE_URL: str = ""
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_SERVICE_KEY: str = ""
    WEATHERNEXT_API_KEY: str = ""
    GEMINI_API_KEY: str = ""
    GOOGLE_SERVICE_ACCOUNT_FILE: str = "service_account.json"
    GOOGLE_CLOUD_PROJECT: str = "weathergpt-509714"
    PORT: int = 8000
    ENVIRONMENT: str = "production"
    CORS_ORIGINS: str = "*"

    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"), 
        env_file_encoding="utf-8", 
        extra="ignore"
    )

settings = Settings()
