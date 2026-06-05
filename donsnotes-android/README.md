# Don's Notes Android App

Native Android app built with Kotlin + Jetpack Compose. Records meeting audio, manages attendees, uploads to the backend API, and displays AI-generated summaries.

## Project Structure

```
app/src/main/java/com/donsnotes/app/
├── DonsNotesApp.kt              # Application class (mock/real toggle)
├── MainActivity.kt              # Main activity with navigation
├── data/
│   ├── model/                   # Data models
│   │   ├── Attendee.kt
│   │   ├── Meeting.kt
│   │   ├── MeetingStatus.kt
│   │   └── AuthModels.kt
│   ├── remote/                  # API client (Retrofit)
│   │   ├── ApiService.kt        # Retrofit interface
│   │   └── RetrofitClient.kt    # OkHttp + Retrofit setup
│   └── local/
│       └── UserPreferences.kt   # DataStore for profile + demo mode
├── ui/
│   ├── theme/                   # Material3 theme
│   │   ├── Color.kt
│   │   ├── Type.kt
│   │   └── Theme.kt
│   ├── meetings/
│   │   ├── MeetingListScreen.kt  # List + hidden demo easter egg
│   │   └── MeetingDetailScreen.kt
│   ├── recording/
│   │   └── RecordingScreen.kt   # Attendee sign-in + SpeechRecognizer + recording
│   ├── contacts/
│   │   └── ContactPickerScreen.kt
│   ├── profile/
│   │   └── ProfileScreen.kt     # Name editor + demo badge + link to plans
│   └── pricing/
│       └── PricingScreen.kt     # Free / Monthly / Lifetime plan cards
├── viewmodel/
│   ├── MeetingViewModel.kt
│   ├── ContactViewModel.kt
│   └── ProfileViewModel.kt      # User name + demo mode toggle
├── service/
│   └── AudioRecorder.kt         # MediaRecorder wrapper (AAC, 44.1kHz)
└── mock/
    └── MockApiService.kt        # Mock API for offline testing
```

## Features

### Attendee Management
- **Manual sign-in** with name + email fields
- **SpeechRecognizer voice input** — tap "Speak to Add" and say "Name, email@example.com"; auto-parses and auto-adds
- **Animated waveform overlay** during voice recognition
- **Quick add** from saved contacts (FilterChips)
- **Auto-save contacts** when new attendees are added

### Audio Recording
- **MediaRecorder** with AAC encoding, 44.1kHz sampling rate, mono
- Start / stop / cancel recording
- Upload & Process flow with progress indicator

### Meeting History & Details
- **Meeting list** with status badges (Pending, Transcribing, etc.) and date
- **Meeting detail** with auto-polling every 5 seconds during processing
- Shows transcript, AI summary, attendee list, organizer name
- **Send Recap Email** button (visible when status is COMPLETED)

### Plans & Pricing
- **Pricing screen** showing all three tiers:
  - **Free**: 15 min/month, basic summaries, 5 attendees
  - **Monthly ($2.70)**: Unlimited, detailed summaries, custom templates
  - **Lifetime ($5)**: 3 hrs/month forever, full summaries, 20 attendees
- Accessible from Profile/Settings → "View Plans & Pricing"
- Owner demo mode unlocks Unlimited

### Owner Demo Mode (Hidden Easter Egg)
- Tap "Don's Notes" title **7 times** to toggle demo mode
- Enables **unlimited transcription** for demo/testing purposes
- Badge shows "DEMO" next to the title when active
- Profile screen shows "Demo / Unlimited" banner
- Pricing screen replaces Free plan with "Free (Demo) — Unlimited"
- Snackbar confirms when toggled on/off

### Profile Settings
- User display name (saved via DataStore, survives restarts)
- Demo mode status badge
- Link to Plans & Pricing

## How to Use Mock Layer
The app defaults to `MockApiService` in `DonsNotesApp.kt`. This allows you to:
1. Tap "+" to create a meeting, add attendees, record audio, and "Upload & Process"
2. See the meeting appear in the list as "Pending"
3. View details — mock service auto-progresses: Pending → Transcribing → Summarizing → Completed
4. Once completed, tap "Send Recap Email"
5. Open Profile → View Plans & Pricing to see the pricing screen
6. Tap "Don's Notes" title 7 times to enable demo mode

To switch to the real backend, update `DonsNotesApp.kt`:
```kotlin
private val useMockApi = false
```

For local development against a backend on the same machine:
```kotlin
RetrofitClient.setBaseUrl("http://10.0.2.2:8000/")
```

## Requirements
- **Target API**: 34 (Android 14+)
- **Kotlin**: 1.9.22
- **Compose BOM**: 2024.01.00
- **Build System**: Gradle 8.5

## Build & Install
```bash
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

## API Contract
The app communicates with:
- `POST /v1/auth/login` — OAuth2 password login
- `POST /v1/auth/signup` — User registration
- `POST /v1/meetings/upload` — Multipart upload (audio + attendees JSON)
- `GET /v1/meetings` — List user meetings
- `GET /v1/meetings/{id}` — Meeting details
- `POST /v1/meetings/{id}/send` — Trigger recap email
- `GET /v1/contacts` — List saved contacts
- `POST /v1/contacts` — Save contact

All endpoints require `Authorization: Bearer <token>` header.