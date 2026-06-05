import SwiftUI

@main
struct DonsNotesApp: App {
    @StateObject var apiService = MockAPIService()

    var body: some Scene {
        WindowGroup {
            MeetingListView(apiService: apiService)
        }
    }
}