import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Don's Notes"
    OPENAI_API_KEY: str = os.getenv("OPENAI_API_KEY", "mock")
    SENDGRID_API_KEY: str = os.getenv("SENDGRID_API_KEY", "mock")
    RESEND_API_KEY: str = os.getenv("RESEND_API_KEY", "mock")
    S3_BUCKET: str = os.getenv("S3_BUCKET", "mock")
    AWS_ACCESS_KEY_ID: str = os.getenv("AWS_ACCESS_KEY_ID", "mock")
    AWS_SECRET_ACCESS_KEY: str = os.getenv("AWS_SECRET_ACCESS_KEY", "mock")
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./sql_app.db")
    
    SECRET_KEY: str = os.getenv("SECRET_KEY", "super-secret-key-for-dev")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 1 week

settings = Settings()
