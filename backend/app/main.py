from fastapi import FastAPI
from app.api.auth import router as auth_router
from app.api.meetings import router as meetings_router
from app.api.contacts import router as contacts_router

app = FastAPI(title="Don's Notes API")

app.include_router(auth_router, prefix="/v1/auth", tags=["auth"])
app.include_router(meetings_router, prefix="/v1/meetings", tags=["meetings"])
app.include_router(contacts_router, prefix="/v1/contacts", tags=["contacts"])

@app.get("/")
def read_root():
    return {"message": "Welcome to Don's Notes API"}
