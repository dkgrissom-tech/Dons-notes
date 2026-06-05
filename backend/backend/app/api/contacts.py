from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from sqlalchemy.orm import Session

from app.schemas.meeting import Contact, ContactCreate
from app.db.session import get_db
from app.db import models
from app.api import deps

router = APIRouter()

@router.get("", response_model=List[Contact])
async def list_contacts(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(deps.get_current_user)
):
    return db.query(models.Contact).filter(models.Contact.user_id == current_user.id).all()

@router.post("", response_model=Contact)
async def create_contact(
    contact_in: ContactCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(deps.get_current_user)
):
    db_obj = models.Contact(
        user_id=current_user.id,
        email=contact_in.email,
        name=contact_in.name,
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj

@router.delete("/{contact_id}")
async def delete_contact(
    contact_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(deps.get_current_user)
):
    contact = db.query(models.Contact).filter(
        models.Contact.id == contact_id,
        models.Contact.user_id == current_user.id
    ).first()
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
    db.delete(contact)
    db.commit()
    return {"message": "Contact deleted"}
