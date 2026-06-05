from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime

class AttendeeBase(BaseModel):
    email: str
    name: Optional[str] = None

class AttendeeCreate(AttendeeBase):
    pass

class Attendee(AttendeeBase):
    id: str
    meeting_id: str

    class Config:
        from_attributes = True

class MeetingBase(BaseModel):
    audio_url: str

class MeetingCreate(MeetingBase):
    pass

class Meeting(MeetingBase):
    id: str
    user_id: str
    transcript: Optional[str] = None
    summary: Optional[str] = None
    status: str
    duration_seconds: Optional[int] = None
    created_at: datetime
    attendees: List[Attendee] = []

    class Config:
        from_attributes = True

class ContactBase(BaseModel):
    email: EmailStr
    name: Optional[str] = None

class ContactCreate(ContactBase):
    pass

class Contact(ContactBase):
    id: str
    user_id: str
    created_at: datetime

    class Config:
        from_attributes = True
