import resend
from app.core.config import settings
from typing import List, Optional
from datetime import datetime

class EmailService:
    def __init__(self):
        resend.api_key = settings.RESEND_API_KEY

    def _build_html(
        self,
        summary: str,
        action_items: Optional[List[str]],
        attendee_names: Optional[List[str]],
        meeting_date: Optional[str],
    ) -> str:
        date_str = meeting_date or datetime.utcnow().strftime("%B %d, %Y")

        # Action items section
        if action_items and len(action_items) > 0:
            items_html = "".join(
                f"""<tr>
                      <td style="padding:6px 0;color:#00e5ff;font-size:13px;vertical-align:top;width:20px;">&#9679;</td>
                      <td style="padding:6px 0;color:#c8d6e5;font-size:13px;line-height:1.5;">{item}</td>
                    </tr>"""
                for item in action_items
            )
            action_block = f"""
            <div style="margin-top:28px;">
              <p style="margin:0 0 12px;font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase;color:#00e5ff;">Action Items</p>
              <table cellpadding="0" cellspacing="0" border="0" width="100%">{items_html}</table>
            </div>"""
        else:
            action_block = ""

        attendees_str = (
            ", ".join(attendee_names) if attendee_names else "—"
        )

        return f"""<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#0a0e1a;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td align="center" style="padding:40px 16px;">
      <table width="600" cellpadding="0" cellspacing="0" border="0" style="max-width:600px;width:100%;background:#0d1525;border-radius:16px;border:1px solid rgba(0,229,255,0.15);overflow:hidden;">

        <!-- Header -->
        <tr>
          <td style="padding:36px 40px 24px;border-bottom:1px solid rgba(0,229,255,0.1);">
            <table width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td>
                  <div style="display:inline-block;width:36px;height:36px;border-radius:50%;background:radial-gradient(circle at 40% 40%,#00e5ff,#005f6b);box-shadow:0 0 16px rgba(0,229,255,0.5);vertical-align:middle;margin-right:10px;"></div>
                  <span style="font-size:22px;font-weight:700;color:#ffffff;vertical-align:middle;letter-spacing:-0.3px;">ORA</span>
                  <span style="font-size:13px;color:#4a6fa5;margin-left:8px;vertical-align:middle;">Meeting Intelligence</span>
                </td>
                <td align="right">
                  <span style="font-size:11px;color:#4a6fa5;">{date_str}</span>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Body -->
        <tr>
          <td style="padding:32px 40px 40px;">

            <p style="margin:0 0 6px;font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase;color:#00e5ff;">Meeting Summary</p>
            <p style="margin:0 0 20px;font-size:15px;color:#c8d6e5;line-height:1.7;">{summary}</p>

            {action_block}

            <!-- Attendees -->
            <div style="margin-top:28px;padding-top:20px;border-top:1px solid rgba(255,255,255,0.06);">
              <p style="margin:0 0 6px;font-size:11px;font-weight:700;letter-spacing:2px;text-transform:uppercase;color:#4a6fa5;">Attendees</p>
              <p style="margin:0;font-size:13px;color:#4a6fa5;">{attendees_str}</p>
            </div>

          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="padding:20px 40px;background:#080d1a;border-top:1px solid rgba(0,229,255,0.08);">
            <p style="margin:0;font-size:11px;color:#2a3a52;text-align:center;">
              Sent by <a href="https://meetora.app" style="color:#00e5ff;text-decoration:none;">ORA</a> · AI Meeting Intelligence
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>"""

    def _build_text(
        self,
        summary: str,
        action_items: Optional[List[str]],
        attendee_names: Optional[List[str]],
        meeting_date: Optional[str],
    ) -> str:
        date_str = meeting_date or datetime.utcnow().strftime("%B %d, %Y")
        lines = [
            f"ORA — Meeting Recap · {date_str}",
            "=" * 48,
            "",
            "SUMMARY",
            summary,
            "",
        ]
        if action_items:
            lines += ["ACTION ITEMS"] + [f"  • {item}" for item in action_items] + [""]
        if attendee_names:
            lines += ["ATTENDEES", ", ".join(attendee_names), ""]
        lines += ["—", "Sent by ORA · AI Meeting Intelligence"]
        return "\n".join(lines)

    async def send_summary(
        self,
        emails: List[str],
        summary: str,
        action_items: Optional[List[str]] = None,
        attendee_names: Optional[List[str]] = None,
        meeting_date: Optional[str] = None,
    ):
        if not settings.RESEND_API_KEY or settings.RESEND_API_KEY == "mock":
            print(f"MOCK EMAIL to {emails}:\n{summary}")
            return True

        date_str = meeting_date or datetime.utcnow().strftime("%B %d, %Y")

        params = {
            "from": "ORA <recap@meetora.app>",
            "to": emails,
            "subject": f"Your Meeting Recap · {date_str}",
            "html": self._build_html(summary, action_items, attendee_names, meeting_date),
            "text": self._build_text(summary, action_items, attendee_names, meeting_date),
        }
        resend.Emails.send(params)
        return True

email_service = EmailService()
