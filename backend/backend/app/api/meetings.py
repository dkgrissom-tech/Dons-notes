from fastapi import APIRouter, UploadFile, File, Form, Depends, HTTPException, BackgroundTasks
from typing import List, Optional
import json
import uuid
from sqlalchemy.orm import Session

from app.schemas.meeting import Meeting, Attendee, AttendeeCreate
from app.services.storage import storage_service
from app.services.transcription import transcription_service
from app.services.summarization import summarization_service
from app.services.email import email_service
from app.db.session import get_db
from app.db import models
from app.api import deps

router = APIRouter()

async def process_meeting(meeting_id: str, db: Session):
    meeting = db.query(models.Meeting).filter(models.Meeting.id == meeting_id).first()
    if not meeting:
        return

    try:
        # Transcription
        meeting.status = "TRANSCRIBING"
        db.commit()
        transcript = await transcription_service.transcribe(meeting.audio_url)
        meeting.transcript = transcript
        
        # Summarization
        meeting.status = "SUMMARIZING"
        db.commit()
        summary = await summarization_service.summarize(transcript)
        meeting.summary = summary
        
        meeting.status = "COMPLETED"
        db.commit()
        
    except Exception as e:
        print(f"Error processing meeting {meeting_id}: {e}")
        meeting.status = "FAILED"
        db.commit()

@router.post("/upload", response_model=Meeting, status_code=201)
async def upload_meeting(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    attendees: str = Form(...),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(deps.get_current_user)
):
    try:
        attendee_list = json.loads(attendees)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid attendees format")

    meeting_id = str(uuid.uuid4())
    
    # Save file to storage
    audio_url = await storage_service.upload_file(file, meeting_id)
    
    # Create meeting record
    db_meeting = models.Meeting(
        id=meeting_id,
        user_id=current_user.id,
        audio_url=audio_url,
        status="PENDING"
    )
    db.add(db_meeting)
    
    for att in attendee_list:
        db_attendee = models.Attendee(
            id=str(uuid.uuid4()),
            meeting_id=meeting_id,
            email=att.get("email"),
            name=att.get("name")
        )
        db.add(db_attendee)
    
    db.commit()
    db.refresh(db_meeting)
    
    # Trigger background processing
    background_tasks.add_task(process_meeting, meeting_id, db)
    
    return db_meeting

@router.get("", response_model=List[Meeting])
async def list_meetings(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(deps.get_current_user)
):
    return db.query(models.Meeting).filter(models.Meeting.user_id == current_user.id).all()

@router.get("/{meeting_id}", response_model=Meeting)
async def get_meeting(
    meeting_id: str, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(deps.get_current_user)
):
    meeting = db.query(models.Meeting).filter(
        models.Meeting.id == meeting_id,
        models.Meeting.user_id == current_user.id
    ).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")
    return meeting

@router.post("/{meeting_id}/send")
async def send_recap(
    meeting_id: str, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(deps.get_current_user)
):
    meeting = db.query(models.Meeting).filter(
        models.Meeting.id == meeting_id,
        models.Meeting.user_id == current_user.id
    ).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")
    
    if not meeting.summary:
        raise HTTPException(status_code=400, detail="Summary not ready yet")
    
    attendees = db.query(models.Attendee).filter(models.Attendee.meeting_id == meeting_id).all()
    emails = [a.email for a in attendees]
    
    await email_service.send_summary(emails, meeting.summary)
    
    meeting.status = "SENT"
    db.commit()
    
    return {"message": "Recap sent successfully"}

@router.post("/{meeting_id}/attendees/sign-in", response_model=Attendee)
async def attendee_sign_in(
    meeting_id: str,
    attendee_in: AttendeeCreate,
    db: Session = Depends(get_db)
):
    # Check if meeting exists
    meeting = db.query(models.Meeting).filter(models.Meeting.id == meeting_id).first()
    if not meeting:
        raise HTTPException(status_code=404, detail="Meeting not found")
    
    # Check if attendee already exists
    db_attendee = db.query(models.Attendee).filter(
        models.Attendee.meeting_id == meeting_id,
        models.Attendee.email == attendee_in.email
    ).first()
    
    if not db_attendee:
        db_attendee = models.Attendee(
            id=str(uuid.uuid4()),
            meeting_id=meeting_id,
            email=attendee_in.email,
            name=attendee_in.name
        )
        db.add(db_attendee)
        db.commit()
        db.refresh(db_attendee)
    
    return db_attendee
