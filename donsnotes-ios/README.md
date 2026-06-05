# Don's Notes iOS App

A powerful meeting transcription and summarization app built with Swift and SwiftUI.

## Features

- 🎤 **High-Quality Audio Recording** - Records meeting conversations with crystal-clear audio
- 🤖 **AI Transcription** - Automatically transcribes meetings using OpenAI Whisper
- 📝 **Smart Summaries** - AI-generated meeting summaries for quick recaps
- 👥 **Attendee Management** - Easily add and manage meeting attendees
- 📧 **Email Recap** - Send meeting summaries directly to attendees
- 💾 **Meeting History** - Access all past meetings with status tracking
- 💳 **Subscription Plans** - Free, Lifetime, and Pro tiers

## Project Structure

```
DonsNotes/
├── DonsNotesApp.swift           # App entry point
├── ContentView.swift            # Main tab navigation
├── Models/
│   └── Meeting.swift            # Data models
├── ViewModels/
│   └── MeetingViewModel.swift   # State management
├── Views/
│   ├── MeetingsView.swift       # Meeting list
│   ├── NewMeetingView.swift     # Recording interface
│   ├── MeetingDetailView.swift  # Meeting details
│   └── ProfileView.swift        # User profile & pricing
├── Services/
│   ├── APIService.swift         # Backend API client
│   └── AudioRecorderManager.swift # Audio recording
└── Extensions/
    └── View+Extensions.swift    # Utilities
```

## Requirements

- iOS 17.0+
- Xcode 16.0+
- macOS for development
- Apple Developer Account (free for testing on your own device)

## Installation & Setup

### Step 1: Clone the Repository
```bash
git clone https://github.com/dkgrissom-tech/Dons-notes.git
cd donsnotes-ios
```

### Step 2: Open in Xcode
```bash
open DonsNotes.xcodeproj
```

### Step 3: Connect Your iPhone
1. Plug your iPhone into your Mac via USB
2. In Xcode, select your device from the device selector (top toolbar)
3. If needed, go to **Window → Devices and Simulators** to verify connection

### Step 4: Configure Signing
1. Select the **DonsNotes** project in the navigator
2. Go to the **Signing & Capabilities** tab
3. Under **Team**, select your Apple Developer account
4. Xcode will auto-generate a provisioning profile

### Step 5: Run the App
1. Press **▶️ Run** (or Cmd+R)
2. On your iPhone, if prompted, go to **Settings → General → VPN & Device Management** and trust your developer profile
3. Open **Don's Notes** from your home screen

## Development

### Project Configuration

**MockAPIService (Default - No Backend Required)**
- All features work fully in demo mode
- Simulates API responses and processing
- Perfect for UI development and testing

**RealAPIService (Production)**
To connect to the actual backend:

1. Open `DonsNotesApp.swift`
2. Change:
   ```swift
   MockAPIService()
   ```
   to:
   ```swift
   RealAPIService(baseURL: URL(string: "YOUR_BACKEND_URL")!)
   ```

### Building for Release

```bash
# Archive for distribution
xcodebuild -scheme DonsNotes -configuration Release -archivePath DonsNotes.xcarchive archive

# Export for App Store
xcodebuild -exportArchive -archivePath DonsNotes.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath .
```

## Architecture

### MVVM Pattern
- **Views**: SwiftUI components for UI
- **ViewModels**: `MeetingViewModel` handles state and business logic
- **Models**: `Meeting`, `User`, `Attendee` data structures

### Services
- **APIService Protocol**: Abstraction for backend communication
- **MockAPIService**: Demo implementation
- **RealAPIService**: Production backend client
- **AudioRecorderManager**: Handles microphone input and audio processing

### Data Flow
1. User records audio on the iPhone
2. App uploads to backend via `APIService`
3. ViewModel polls for processing status
4. When complete, app displays transcript and summary
5. User can send recap to attendees

## Permissions

The app requires the following permissions:
- **Microphone Access** - To record meetings
- **Contacts** - (Optional) To suggest attendees from contacts

Request these in your app's `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access to record your meetings</string>
```

## API Integration

### Base URL Configuration
Update the backend URL in `RealAPIService.swift`:
```swift
let baseURL = URL(string: "https://your-api.com")!
```

### Required Backend Endpoints
- `POST /auth/user` - Get current user
- `GET /meetings` - List user's meetings
- `GET /meetings/{id}` - Get meeting details
- `POST /meetings/upload` - Upload new meeting with audio
- `POST /meetings/{id}/send` - Send recap email

## Troubleshooting

### "Untrusted Developer" Alert
1. Go to **Settings → General → VPN & Device Management**
2. Find your developer profile
3. Tap **Trust**

### Recording Permission Denied
1. Go to **Settings → Privacy & Security → Microphone**
2. Ensure **Don's Notes** is allowed

### App Not Appearing on Device
1. Disconnect and reconnect iPhone
2. Restart Xcode
3. Go to **Window → Devices and Simulators** to verify connection

### Build Failures
1. Clean build folder: **Cmd+Shift+K**
2. Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
3. Rebuild: **Cmd+B**

## Testing

### Testing Recording
1. Tap **New** tab
2. Enter meeting title
3. Add at least one attendee
4. Tap **Start Recording**
5. Speak clearly for a few seconds
6. Tap **Stop Recording**
7. Tap **Upload**

### Testing Mock API
The app works fully in mock mode with simulated:
- Meeting status progression
- Transcript generation
- Summary creation
- Processing delays

## Contributing

1. Create a new branch: `git checkout -b feature/your-feature`
2. Make your changes
3. Commit: `git commit -am 'Add feature'`
4. Push: `git push origin feature/your-feature`
5. Create a Pull Request

## Support

For issues, questions, or feedback:
- 📧 Email: support@donsnotes.com
- 🐛 Report bugs on GitHub Issues
- 💡 Suggest features on GitHub Discussions

## License

This project is proprietary. All rights reserved.

## Changelog

### Version 1.0 (Initial Release)
- ✅ Audio recording with high quality
- ✅ Meeting management (create, view, delete)
- ✅ Attendee management
- ✅ Meeting history
- ✅ User profile and settings
- ✅ Subscription plans display
- ✅ Mock API for demo mode
