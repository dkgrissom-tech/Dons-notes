import SwiftUI

extension Notification.Name {
    static let startRecording = Notification.Name("startRecording")
}

// MARK: - Design Tokens
struct DNColors {
    static let background = Color(red: 0.06, green: 0.07, blue: 0.10)
    static let surface = Color(red: 0.10, green: 0.12, blue: 0.17)
    static let surfaceElevated = Color(red: 0.13, green: 0.16, blue: 0.22)
    static let accent = Color(red: 0.22, green: 0.55, blue: 1.0)
    static let accentGlow = Color(red: 0.22, green: 0.55, blue: 1.0).opacity(0.15)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.65)
    static let textTertiary = Color(white: 0.42)
    static let divider = Color(white: 1.0).opacity(0.06)
    static let successGreen = Color(red: 0.2, green: 0.85, blue: 0.6)
    static let warningAmber = Color(red: 1.0, green: 0.75, blue: 0.2)
}

struct MeetingListView<T: APIServiceProtocol>: View {
    @ObservedObject var apiService: T
    @State private var meetings: [Meeting] = []
    @State private var isShowingRecording = false
    @State private var isShowingProfile = false
    @State private var isShowingPricing = false
    @State private var isLoading = false
    @State private var searchText = ""
    
    private let hasSeenPricingKey = "has_seen_pricing_v1"
    
    var filteredMeetings: [Meeting] {
        if searchText.isEmpty { return meetings }
        let q = searchText.lowercased()
        return meetings.filter {
            ($0.summary?.lowercased().contains(q) ?? false) ||
            ($0.transcript?.lowercased().contains(q) ?? false) ||
            $0.attendees.contains(where: { $0.name.lowercased().contains(q) || $0.email.lowercased().contains(q) }) ||
            ($0.organizerName?.lowercased().contains(q) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DNColors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(DNColors.textTertiary)
                            .font(.system(size: 15))
                        TextField("", text: $searchText)
                            .placeholder(when: searchText.isEmpty) {
                                Text("Search meetings...").foregroundColor(DNColors.textTertiary)
                            }
                            .foregroundColor(DNColors.textPrimary)
                            .font(.system(size: 15))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(DNColors.textTertiary)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(DNColors.surface)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    
                    if isLoading && meetings.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: DNColors.accent))
                                .scaleEffect(1.3)
                            Text("Loading meetings...")
                                .font(.system(size: 14))
                                .foregroundColor(DNColors.textSecondary)
                        }
                        Spacer()
                    } else if filteredMeetings.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: searchText.isEmpty ? "waveform.badge.mic" : "magnifyingglass")
                                .font(.system(size: 44))
                                .foregroundColor(DNColors.textTertiary)
                            Text(searchText.isEmpty ? "No meetings yet" : "No results found")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(DNColors.textSecondary)
                            if searchText.isEmpty {
                                Text("Tap + to record your first meeting")
                                    .font(.system(size: 14))
                                    .foregroundColor(DNColors.textTertiary)
                            }
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredMeetings) { meeting in
                                    NavigationLink(destination: MeetingDetailView(meeting: meeting, apiService: apiService)) {
                                        MeetingCard(meeting: meeting)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("Don's Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 4) {
                        Button(action: { isShowingProfile = true }) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 18))
                                .foregroundColor(DNColors.textSecondary)
                        }
                        Button(action: { isShowingRecording = true }) {
                            ZStack {
                                Circle()
                                    .fill(DNColors.accent)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15))
                            .foregroundColor(DNColors.textSecondary)
                    }
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
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
        .preferredColorScheme(.dark)
    }
    
    func refresh() {
        isLoading = true
        Task {
            do {
                let fetchedMeetings = try await apiService.fetchMeetings()
                await MainActor.run {
                    self.meetings = fetchedMeetings.sorted(by: { $0.createdAt > $1.createdAt })
                    MeetingCacheService.shared.saveMeetings(self.meetings)
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Meeting Card
struct MeetingCard: View {
    let meeting: Meeting
    
    private var dateString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: meeting.createdAt)
    }
    
    private var previewText: String {
        if let summary = meeting.summary, !summary.isEmpty {
            return summary.prefix(120) + (summary.count > 120 ? "..." : "")
        }
        return "Processing..."
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateString)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DNColors.textPrimary)
                    if let organizer = meeting.organizerName, !organizer.isEmpty {
                        Text(organizer)
                            .font(.system(size: 12))
                            .foregroundColor(DNColors.textTertiary)
                    }
                }
                Spacer()
                StatusPill(status: meeting.status)
            }
            
            // Preview
            Text(previewText)
                .font(.system(size: 14))
                .foregroundColor(DNColors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Footer
            HStack(spacing: 16) {
                if !meeting.attendees.isEmpty {
                    Label("\(meeting.attendees.count) attendee\(meeting.attendees.count == 1 ? "" : "s")", systemImage: "person.2")
                        .font(.system(size: 12))
                        .foregroundColor(DNColors.textTertiary)
                }
                if let items = meeting.actionItems, !items.isEmpty {
                    Label("\(items.count) action\(items.count == 1 ? "" : "s")", systemImage: "checkmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(DNColors.accent.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DNColors.textTertiary)
            }
        }
        .padding(16)
        .background(DNColors.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(meeting.status.isProcessing ? DNColors.accent.opacity(0.3) : DNColors.divider, lineWidth: 1)
        )
    }
}

// MARK: - Status Pill
struct StatusPill: View {
    let status: MeetingStatus
    var body: some View {
        Text(status.displayName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .cornerRadius(20)
    }
}

// MARK: - TextField Placeholder Extension
extension View {
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
