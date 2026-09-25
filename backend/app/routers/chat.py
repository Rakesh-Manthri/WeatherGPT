from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from ..services import ai_service

router = APIRouter()

class ChatRequest(BaseModel):
    message: str
    lat: float | None = None
    lon: float | None = None
    session_id: str | None = None
    language: str | None = None

class ChatResponse(BaseModel):
    reply: str
    weather_context_used: bool = False

@router.post("/completions", response_model=ChatResponse)
async def chat_completions(req: ChatRequest):
    if not ai_service.ai_agent:
        # Fallback if Gemini key is missing
        return ChatResponse(
            reply="AI agent is not initialized. Please check GEMINI_API_KEY.",
            weather_context_used=False
        )
        
    context_prefix = ""
    if req.language:
        context_prefix += f"[Respond in {req.language}] "
    if req.lat and req.lon:
        context_prefix += f"[User's current location: {req.lat}, {req.lon}] "

    # Process via Generative AI
    reply = await ai_service.ai_agent.get_response(
        user_message=context_prefix + req.message,
        session_id=req.session_id or "default"
    )
    
    return ChatResponse(
        reply=reply,
        weather_context_used=True
    )
