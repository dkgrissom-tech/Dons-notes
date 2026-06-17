import json
import os
import httpx
from app.core.config import settings

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_MODEL   = "llama-3.3-70b-versatile"
GROQ_URL     = "https://api.groq.com/openai/v1/chat/completions"

SYSTEM_PROMPT = """You are ORA, an AI meeting intelligence assistant.
Analyze the transcript and return ONLY valid JSON in this exact shape:
{
  "summary": "2-4 sentence narrative recap of the meeting",
  "action_items": ["action item 1", "action item 2"]
}
Rules:
- summary: clear, professional prose — what was discussed and decided
- action_items: concrete next steps with owner names if mentioned, max 8 items
- If no clear action items exist, use an empty array []
- Return ONLY the JSON object, no markdown, no commentary"""

class SummarizationService:

    async def summarize_structured(self, transcript: str) -> dict:
        """Returns {"summary": str, "action_items": [str]}"""
        if not transcript or len(transcript.strip()) < 20:
            return {"summary": "No transcript content to summarize.", "action_items": []}

        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                GROQ_URL,
                headers={
                    "Authorization": f"Bearer {GROQ_API_KEY}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": GROQ_MODEL,
                    "max_tokens": 512,
                    "temperature": 0.3,
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": f"Meeting transcript:\n{transcript[:4000]}"},
                    ],
                },
            )

        if resp.status_code != 200:
            raise RuntimeError(f"Groq HTTP {resp.status_code}: {resp.text[:200]}")

        content = resp.json()["choices"][0]["message"]["content"].strip()

        # Parse JSON — strip any accidental markdown fences
        if content.startswith("```"):
            content = content.split("```")[1]
            if content.startswith("json"):
                content = content[4:]

        try:
            return json.loads(content)
        except json.JSONDecodeError:
            # Fallback: treat entire content as summary
            return {"summary": content, "action_items": []}

    async def summarize(self, transcript: str) -> str:
        """Legacy single-string interface — returns summary only."""
        result = await self.summarize_structured(transcript)
        return result.get("summary", "")

summarization_service = SummarizationService()
