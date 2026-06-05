# Don's Notes — iPhone 17 Setup Guide

## Quick Start: Install on Your iPhone 17

### Prerequisites
- A Mac with **Xcode 16+** installed
- Your **iPhone 17** connected via USB (or wirelessly)
- An **Apple Developer account** (free is fine for testing on your own device)

### Step 1: Open the Project
1. Open **Finder** and navigate to the project folder
2. Double-click `DonsNotes.xcodeproj` — it opens in Xcode automatically
3. Wait for Xcode to finish indexing (a few seconds)

### Step 2: Connect Your iPhone
1. Plug your iPhone 17 into your Mac via USB
2. In Xcode's top toolbar, click the device selector (next to the play button)
3. Select your iPhone 17 from the list
4. If it doesn't appear, go to **Window → Devices and Simulators** to verify it's connected

### Step 3: Sign & Run
1. In Xcode, select **DonsNotes** from the project navigator (left sidebar)
2. Go to the **Signing & Capabilities** tab
3. Under **Team**, select your Apple Developer account (or "Add an Account" if not set up)
4. Xcode will auto-generate a provisioning profile
5. Press **▶️ Run** (or Cmd+R)

### Step 4: First Launch
1. On your iPhone, you may see a "Untrusted Developer" alert
2. Go to **Settings → General → VPN & Device Management**
3. Tap your developer profile → tap **Trust**
4. Open the **Don's Notes** app from your home screen

### What's Included in the App
- **Record meeting** — Tap the + button, add attendees (type or speak), then tap the mic to record
- **Voice attendee input** — Tap the 🎤 button and say "Jane Smith, jane@example.com"
- **Saved contacts** — Past attendees are auto-saved for quick re-selection
- **Meeting history** — All past meetings with status indicators
- **AI summaries** — Transcript and AI-generated summary for each meeting
- **Send recap** — One-tap to email the summary to all attendees
- **Profile settings** — Gear icon to set your name
- **Pricing** — Plans screen showing Free, $5 Lifetime, and $2.70/mo options

### Demo Mode (Owner's Free Copy)
The app uses **MockAPIService** by default, which means it works fully without any backend running:
- Recordings simulate processing (Pending → Transcribing → Summarizing → Completed)
- All features are unlimited for demo use
- No API keys or backend setup needed

### Switching to Production (Later)
When you're ready to connect to the real backend:
1. Open `DonsNotesApp.swift` in Xcode
2. Comment out `MockAPIService()` and uncomment `RealAPIService()`
3. Update the backend URL in `RealAPIService.swift`

### Need Help?
- Project location: `XcodeProject/DonsNotes.xcodeproj`
- Backend API: Backend code in `/home/team/shared/backend/`
- Questions? Just ask Don's Notes team!