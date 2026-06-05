# Don's Notes iOS App

Native iOS app built with SwiftUI, AVFoundation, and URLSession.

## Project Structure
The project is organized into:
- `Sources/Models`: Data structures (Meeting, Attendee).
- `Sources/Views`: SwiftUI views for Recording, List, and Details.
- `Sources/Services`: Business logic for API communication and Audio Recording.
- `Sources/Mocks`: Mock data and services for testing without a backend.

## How to use Mock Layer
The app is configured to use `MockAPIService` by default in `DonsNotesApp.swift`. This allows you to:
1.  **Record a meeting**: Click the "+" button, record, add attendees, and "Upload".
2.  **See processing**: The meeting will appear in the list as "Pending".
3.  **Automatic progression**: The mock service simulates the backend's progression from `Pending` -> `Transcribing` -> `Summarizing` -> `Completed` every 5 seconds when viewing the details.
4.  **Send recap**: Once completed, you can test the "Send Recap Email" button.

To switch to the real backend, uncomment `RealAPIService` in `DonsNotesApp.swift`.

## Target
- iOS 17.0+
- SwiftUI
