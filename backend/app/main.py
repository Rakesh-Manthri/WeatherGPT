from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from .config import settings
from .routers import weather, chat
from .services.ai_service import init_ai_agent

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup logic
    print(f"[WeatherGPT Backend] Environment: {settings.ENVIRONMENT}")
    print(f"[WeatherGPT Backend] Initializing AI Agent... (Key present: {bool(settings.GEMINI_API_KEY)})")
    if not settings.GEMINI_API_KEY:
        print("[WARNING] GEMINI_API_KEY is not set! AI completions will return fallback message.")
    init_ai_agent(settings.GEMINI_API_KEY)
    yield
    # Shutdown logic

app = FastAPI(
    title="WeatherGPT API",
    description="Production Backend API for WeatherGPT (Open-Meteo + Gemini + Supabase)",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configure CORS for mobile apps, web preview, and local development
origins = [origin.strip() for origin in settings.CORS_ORIGINS.split(",") if origin.strip()] or ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(weather.router, prefix="/api/weather", tags=["weather"])
app.include_router(chat.router, prefix="/api/chat", tags=["chat"])

@app.get("/", tags=["root"])
async def root():
    return {
        "name": "WeatherGPT API",
        "status": "online",
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT,
        "docs": "/docs",
        "health": "/health",
    }

@app.get("/health", tags=["health"])
async def health_check():
    return {
        "status": "healthy",
        "version": "1.0.0",
        "environment": settings.ENVIRONMENT,
        "ai_ready": bool(settings.GEMINI_API_KEY),
    }
