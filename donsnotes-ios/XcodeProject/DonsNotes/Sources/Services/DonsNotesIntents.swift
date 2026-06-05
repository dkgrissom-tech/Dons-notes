import AppIntents
import SwiftUI

struct RecordMeetingIntent: AppIntent {
    static var title: LocalizedStringResource = "Record Meeting"
    static var description = IntentDescription("Start a new meeting recording in Don's Notes.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // In a real app, we might trigger a deep link or set a flag in a shared service
        // For now, we'll just open the app which will handle the intent
        return .result()
    }
}

struct DonsNotesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordMeetingIntent(),
            phrases: [
                "Start a recording in \(.applicationName)",
                "Record a meeting with \(.applicationName)",
                "New meeting in \(.applicationName)"
            ],
            shortTitle: "Record Meeting",
            systemImageName: "mic.circle"
        )
    }
}
