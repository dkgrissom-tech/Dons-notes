import boto3
import os
import shutil
from fastapi import UploadFile
from app.core.config import settings

class StorageService:
    def __init__(self):
        self.upload_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data")
        if not os.path.exists(self.upload_dir):
            os.makedirs(self.upload_dir)
        
        self.s3 = boto3.client(
            's3',
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY
        )

    async def upload_file(self, file: UploadFile, meeting_id: str) -> str:
        file_path = os.path.join(self.upload_dir, f"{meeting_id}_{file.filename}")
        
        # Save locally first
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        if settings.AWS_ACCESS_KEY_ID == "mock":
            return f"file://{os.path.abspath(file_path)}"

        # Real S3 upload
        s3_key = f"recordings/{meeting_id}_{file.filename}"
        self.s3.upload_file(file_path, settings.S3_BUCKET, s3_key)
        return f"s3://{settings.S3_BUCKET}/{s3_key}"

storage_service = StorageService()
