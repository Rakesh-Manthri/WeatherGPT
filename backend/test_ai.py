import asyncio
from dotenv import load_dotenv
import os
import sys

# Load .env from root
load_dotenv(dotenv_path="../.env")

# Must set before importing to configure settings
sys.path.append(os.path.dirname(__file__))

from app.services.ai_service import init_ai_agent
from app.config import settings

async def test():
    print(f"Gemini Key loaded: {bool(settings.GEMINI_API_KEY)}")
    agent = init_ai_agent(settings.GEMINI_API_KEY)
    
    # Simulate a request from Delhi (28.6139, 77.2090)
    query = "What is the weather right now?"
    context = "[User's current location: 28.6139, 77.2090] "
    
    print("Asking AI...")
    response = await agent.get_response(context + query, session_id="test")
    print("\n--- AI Response ---")
    print(response)
    print("-------------------")

if __name__ == "__main__":
    asyncio.run(test())
