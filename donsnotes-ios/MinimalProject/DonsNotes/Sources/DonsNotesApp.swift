import SwiftUI

@main
struct DonsNotesApp: App {
    @StateObject private var apiService = RealAPIService()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                MeetingListView(apiService: apiService)
            } else {
                OnboardingView()
            }
        }
    }
}
