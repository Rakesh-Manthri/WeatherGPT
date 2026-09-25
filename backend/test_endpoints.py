import os
import sys
from dotenv import load_dotenv

# Load env variables from root .env
load_dotenv(dotenv_path="../.env")

from fastapi.testclient import TestClient
from app.main import app
from app.config import settings
from app.services.ai_service import init_ai_agent

def run_tests():
    print("==========================================")
    print("       TESTING WEATHERGPT BACKEND API     ")
    print("==========================================")
    
    # 1. Initialize AI Agent if key exists
    if settings.GEMINI_API_KEY:
        print(f"[+] GEMINI_API_KEY detected: {settings.GEMINI_API_KEY[:6]}...")
        init_ai_agent(settings.GEMINI_API_KEY)
    else:
        print("[!] WARNING: GEMINI_API_KEY is missing or empty.")

    client = TestClient(app)

    # Test 1: GET /health
    print("\n--- 1. Testing GET /health ---")
    res = client.get("/health")
    print(f"Status: {res.status_code}")
    print(f"Response: {res.json()}")
    assert res.status_code == 200

    # Test 2: GET /api/weather/current
    print("\n--- 2. Testing GET /api/weather/current ---")
    res = client.get("/api/weather/current?lat=28.6139&lon=77.2090")
    print(f"Status: {res.status_code}")
    print(f"Response: {res.json()}")
    assert res.status_code == 200

    # Test 3: GET /api/weather/forecast
    print("\n--- 3. Testing GET /api/weather/forecast ---")
    res = client.get("/api/weather/forecast?lat=28.6139&lon=77.2090&days=3")
    print(f"Status: {res.status_code}")
    print(f"Response: {res.json()}")
    assert res.status_code == 200

    # Test 4: POST /api/chat/completions
    print("\n--- 4. Testing POST /api/chat/completions ---")
    payload = {
        "message": "What is the weather right now?",
        "lat": 28.6139,
        "lon": 77.2090,
        "session_id": "test_session_1"
    }
    print(f"Sending payload: {payload}")
    res = client.post("/api/chat/completions", json=payload)
    print(f"Status: {res.status_code}")
    print(f"Response: {res.json()}")
    assert res.status_code == 200

    print("\n==========================================")
    print("       ALL API ENDPOINTS TESTED SUCCESSFULLY! ")
    print("==========================================")

if __name__ == "__main__":
    run_tests()
