import openai
from app.core.config import settings

class SummarizationService:
    def __init__(self):
        self.client = openai.OpenAI(api_key=settings.OPENAI_API_KEY)

    async def summarize(self, transcript: str) -> str:
        if not settings.OPENAI_API_KEY or settings.OPENAI_API_KEY == "mock":
            return "This is a mock summary. Please provide a real OpenAI API key."
        
        response = self.client.chat.completions.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": "Summarize the following meeting transcript into a concise recap with action items."},
                {"role": "user", "content": transcript}
            ]
        )
        return response.choices[0].message.content

summarization_service = SummarizationService()
