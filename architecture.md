# Don's Notes System Architecture

## Overview
Don's Notes is a service that transcribes voice notes, summarizes them using AI, and emails the recap to meeting attendees.

## Components

### 1. iOS App (Swift/SwiftUI)
- Records high-quality audio.
- Manages contacts/attendees.
- Communicates with the Backend API.
- Displays meeting history and status.

### 2. Backend API (FastAPI)
- Handles authentication and user management.
- Manages meeting lifecycle (upload -> transcription -> summary -> email).
- Integrates with external APIs (OpenAI, Email Provider).
- Processes long-running tasks asynchronously.

### 3. Database (SQLite/Turso)
- Shared database for users, meetings, and attendees.

### 4. Storage (S3/Object Storage)
- Stores raw .m4a/.wav audio files.

## Data Models

### User
- `id`: UUID
- `email`: String
- `name`: String
- `subscription_tier`: Enum (FREE, LIFETIME, MONTHLY)
- `transcription_minutes_used`: Integer

### Meeting
- `id`: UUID
- `user_id`: UUID (FK)
- `audio_url`: String
- `transcript`: Text
- `summary`: Text
- `status`: Enum (UPLOADING, PENDING, TRANSCRIBING, SUMMARIZING, COMPLETED, SENT, FAILED)
- `created_at`: Timestamp

### Attendee
- `id`: UUID
- `meeting_id`: UUID (FK)
- `email`: String
- `name`: String (Optional)

## API Endpoints

### Authentication
- `POST /auth/login`: (TBD: Magic link or Auth0)

### Meetings
- `POST /meetings/upload`: Uploads audio file and metadata.
    - Multipart body: `file`, `attendees` (JSON string).
- `GET /meetings/{id}`: Returns meeting status, transcript, and summary.
- `GET /meetings`: Returns a list of user's meetings.
- `POST /meetings/{id}/send`: Triggers the email delivery.

## Sequence Flow
1. **iOS App** records audio.
2. **iOS App** calls `POST /meetings/upload`.
3. **Backend** saves audio, creates DB record, returns `meeting_id`.
4. **Backend** (Background Worker):
    a. Calls **OpenAI Whisper** for transcription. Updates DB.
    b. Calls **OpenAI GPT** for summarization. Updates DB.
    c. (If auto-send enabled) Calls **Email Service**.
5. **iOS App** polls `GET /meetings/{id}` or receives push notification.
