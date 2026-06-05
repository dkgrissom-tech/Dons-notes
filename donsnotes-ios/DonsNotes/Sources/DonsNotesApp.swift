import SwiftUI

@main
struct DonsNotesApp: App {
    // Toggle this to switch between Mock and Real API
    @StateObject var apiService = MockAPIService()
    // @StateObject var apiService = RealAPIService()

    var body: some Scene {
        WindowGroup {
            MeetingListView(apiService: apiService)
        }
    }
}
