import openai
import os
from app.core.config import settings

class TranscriptionService:
    def __init__(self):
        self.client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)

    async def transcribe(self, audio_file_path: str) -> str:
        if not settings.OPENAI_API_KEY or settings.OPENAI_API_KEY == "mock":
            return "This is a mock transcript. Please provide a real OpenAI API key."
        
        # Audio file path is likely a local path in this mock
        path = audio_file_path.replace("file://", "")
        with open(path, "rb") as audio_file:
            transcript = self.client.audio.transcriptions.create(
                model="whisper-1", 
                file=audio_file
            )
        return transcript.text

transcription_service = TranscriptionService()
