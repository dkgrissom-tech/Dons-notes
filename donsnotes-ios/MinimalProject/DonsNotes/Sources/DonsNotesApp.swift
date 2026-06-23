import SwiftUI

@main
struct DonsNotesApp: App {
    @StateObject private var apiService = RealAPIService()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var groqReachableOnLaunch: Bool? = nil

    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenOnboarding {
                    MeetingListView(apiService: apiService)
                } else {
                    OnboardingView()
                }
            }
            .task { await pingGroq() }
        }
    }

    /// Best-effort reachability check at launch. Never blocks UI.
    /// A cheap 1-token chat call verifies the API key + network in one shot.
    private func pingGroq() async {
        do {
            _ = try await GroqClient.chat(
                messages: [.init(role: "user", content: "ping")],
                temperature: 0,
                timeoutSeconds: 4
            )
            groqReachableOnLaunch = true
        } catch {
            groqReachableOnLaunch = false
        }
    }
}
