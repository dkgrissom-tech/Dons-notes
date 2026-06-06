import SwiftUI

extension Notification.Name {
    static let startRecording = Notification.Name("startRecording")
}

struct MeetingListView<T: APIServiceProtocol>: View {
    @ObservedObject var apiService: T
    @State private var meetings: [Meeting] = []
    @State private var isShowingRecording = false
    @State private var isShowingProfile = false
    @State private var isShowingPricing = false
    @State private var isLoading = false
    
    private let hasSeenPricingKey = "has_seen_pricing_v1"
    var body: some View {
        NavigationView {
            VStack {
                if isLoading && meetings.isEmpty {
                    ProgressView()
                } else {
                    List(meetings) { meeting in
                        NavigationLink(destination: MeetingDetailView(meeting: meeting, apiService: apiService)) {
                            VStack(alignment: .leading) {
                                Text(meeting.createdAt, style: .date)
                                    .font(.headline)
                                HStack {
                                    Text(meeting.status.displayName)
                                        .font(.subheadline)
                                        .foregroundColor(meeting.status.color)
                                    Spacer()
                                    Text("\(meeting.attendees.count) attendees")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Don's Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            isShowingProfile = true
                        }) {
                            Image(systemName: "gearshape")
                        }
                        
                        Button(action: {
                            isShowingRecording = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $isShowingRecording, onDismiss: refresh) {
                RecordingView(apiService: apiService)
            }
            .sheet(isPresented: $isShowingProfile) {
                ProfileView()
            }
            .sheet(isPresented: $isShowingPricing) {
                PlansView()
            }
            .onAppear {
                self.meetings = MeetingCacheService.shared.loadMeetings()
                refresh()
                
                if !UserDefaults.standard.bool(forKey: hasSeenPricingKey) {
                    isShowingPricing = true
                    UserDefaults.standard.set(true, forKey: hasSeenPricingKey)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .startRecording)) { _ in
                isShowingRecording = true
            }
        }
    }
    
    func refresh() {
        isLoading = true
        Task {
            do {
                let fetchedMeetings = try await apiService.fetchMeetings()
                await MainActor.run {
                    self.meetings = fetchedMeetings.sorted(by: { $0.createdAt > $1.createdAt })
                    isLoading = false
                }
            } catch {
                print("Failed to fetch meetings: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}
