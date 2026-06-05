from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Integer
from sqlalchemy.orm import relationship
from app.db.session import Base
import datetime
import uuid

class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    email = Column(String, unique=True, index=True)
    name = Column(String, nullable=True)
    hashed_password = Column(String)
    subscription_tier = Column(String, default="FREE")  # FREE, LIFETIME, MONTHLY
    transcription_minutes_used = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    meetings = relationship("Meeting", back_populates="user")

class Meeting(Base):
    __tablename__ = "meetings"

    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"))
    audio_url = Column(String)
    transcript = Column(Text, nullable=True)
    summary = Column(Text, nullable=True)
    status = Column(String)  # UPLOADING, PENDING, TRANSCRIBING, SUMMARIZING, COMPLETED, SENT, FAILED
    duration_seconds = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="meetings")
    attendees = relationship("Attendee", back_populates="meeting")

class Attendee(Base):
    __tablename__ = "attendees"

    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    meeting_id = Column(String, ForeignKey("meetings.id"))
    email = Column(String)
    name = Column(String, nullable=True)

    meeting = relationship("Meeting", back_populates="attendees")

class Contact(Base):
    __tablename__ = "contacts"

    id = Column(String, primary_key=True, index=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"))
    email = Column(String)
    name = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
