import resend
from app.core.config import settings
from typing import List

class EmailService:
    def __init__(self):
        resend.api_key = settings.RESEND_API_KEY

    async def send_summary(self, emails: List[str], summary: str):
        if not settings.RESEND_API_KEY or settings.RESEND_API_KEY == "mock":
            print(f"MOCK EMAIL to {emails}: {summary}")
            return True
        
        params = {
            "from": "Don's Notes <recap@donsnotes.com>",
            "to": emails,
            "subject": "Meeting Recap",
            "text": summary,
        }
        resend.Emails.send(params)
        return True

email_service = EmailService()
