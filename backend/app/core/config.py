import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")
    
    PROJECT_NAME: str = "Don's Notes"
    OPENAI_API_KEY: str = "mock"
    SENDGRID_API_KEY: str = "mock"
    RESEND_API_KEY: str = "mock"
    S3_BUCKET: str = "mock"
    AWS_ACCESS_KEY_ID: str = "mock"
    AWS_SECRET_ACCESS_KEY: str = "mock"
    DATABASE_URL: str = "sqlite:///./sql_app.db"
    
    SECRET_KEY: str = "super-secret-key-for-dev"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 1 week

settings = Settings()
