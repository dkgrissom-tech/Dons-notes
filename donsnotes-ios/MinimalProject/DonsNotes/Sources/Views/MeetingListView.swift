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
    @State private var searchText = ""


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
                LM.Colors.void.ignoresSafeArea()

                // Subtle grid background
                GeometryReader { geo in
                    Path { p in
                        let s: CGFloat = 44
                        var x: CGFloat = 0
                        while x < geo.size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: geo.size.height)); x += s }
                        var y: CGFloat = 0
                        while y < geo.size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y)); y += s }
                    }
                    .stroke(LM.Colors.cyan.opacity(0.03), lineWidth: 0.5)
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(LM.Fonts.text(14))
                            .foregroundColor(LM.Colors.textTertiary)
                        TextField("", text: $searchText)
                            .placeholder(when: searchText.isEmpty) {
                                Text("Search meetings...").foregroundColor(LM.Colors.textGhost)
                            }
                            .foregroundColor(LM.Colors.textPrimary)
                            .font(LM.Fonts.text(14))
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(LM.Colors.textTertiary)
                                    .font(LM.Fonts.text(13))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(LM.Colors.surface)
                    .cornerRadius(LM.Radius.sm)
                    .overlay(RoundedRectangle(cornerRadius: LM.Radius.sm).stroke(LM.Colors.borderDim, lineWidth: 1))
                    .padding(.horizontal, LM.Space.md)
                    .padding(.top, LM.Space.sm)
                    .padding(.bottom, LM.Space.md)

                    if isLoading && meetings.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            LUMENOrbView(state: .idle, speechService: SpeechRecognizerService.preview, size: 80)
                            Text("LOADING...")
                                .font(LM.Fonts.mono(11, weight: .bold))
                                .foregroundColor(LM.Colors.textTertiary)
                                .tracking(3)
                        }
                        Spacer()
                    } else if filteredMeetings.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            LUMENOrbView(state: .dormant, speechService: SpeechRecognizerService.preview, size: 80)
                            Text(searchText.isEmpty ? "NO MEETINGS YET" : "NO RESULTS FOUND")
                                .font(LM.Fonts.mono(12, weight: .bold))
                                .foregroundColor(LM.Colors.textTertiary)
                                .tracking(2)
                            if searchText.isEmpty {
                                Text("Tap + to start your first meeting")
                                    .font(LM.Fonts.text(13))
                                    .foregroundColor(LM.Colors.textGhost)
                            }
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredMeetings) { meeting in
                                    NavigationLink(destination: MeetingDetailView(meeting: meeting, apiService: apiService)) {
                                        LUMENMeetingCard(meeting: meeting)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, LM.Space.md)
                            .padding(.bottom, LM.Space.xl)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("O  R  A")
                        .font(.system(size: 20, weight: .thin, design: .default))
                        .tracking(8)
                        .foregroundColor(.white)
                        .kerning(0)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 10) {
                        Button(action: { isShowingProfile = true }) {
                            Image(systemName: "person.circle")
                                .font(LM.Fonts.text(17))
                                .foregroundColor(LM.Colors.textSecondary)
                        }
                        Button(action: { isShowingRecording = true }) {
                            ZStack {
                                Circle()
                                    .fill(LM.Colors.cyan)
                                    .frame(width: 32, height: 32)
                                    .shadow(color: LM.Colors.cyan.opacity(0.5), radius: 8)
                                Image(systemName: "plus")
                                    .font(LM.Fonts.text(14, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(LM.Fonts.text(14))
                            .foregroundColor(isLoading ? LM.Colors.cyan : LM.Colors.textSecondary)
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
                meetings = MeetingCacheService.shared.loadMeetings()
                refresh()
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
                let fetched = try await apiService.fetchMeetings()
                await MainActor.run {
                    meetings = fetched.sorted(by: { $0.createdAt > $1.createdAt })
                    MeetingCacheService.shared.saveMeetings(meetings)
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - LUMEN Meeting Card
struct LUMENMeetingCard: View {
    let meeting: Meeting

    private var dateString: String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: meeting.createdAt)
    }

    private var preview: String {
        if let s = meeting.summary, !s.isEmpty { return String(s.prefix(110)) + (s.count > 110 ? "..." : "") }
        return meeting.status.isProcessing ? "Processing with LUMEN..." : "Tap to view"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            Rectangle()
                .fill(meeting.status.isProcessing ? LM.Colors.cyan : LM.Colors.cyan.opacity(0.3))
                .frame(width: 3)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(dateString)
                            .font(LM.Fonts.text(15, weight: .semibold))
                            .foregroundColor(LM.Colors.textPrimary)
                        if let org = meeting.organizerName, !org.isEmpty {
                            Text(org)
                                .font(LM.Fonts.mono(10))
                                .foregroundColor(LM.Colors.textTertiary)
                                .tracking(0.5)
                        }
                    }
                    Spacer()
                    LUMENStatusBadge(status: meeting.status)
                }

                // Preview
                Text(preview)
                    .font(LM.Fonts.text(13))
                    .foregroundColor(LM.Colors.textSecondary)
                    .lineLimit(2)

                // Footer
                HStack(spacing: 14) {
                    if !meeting.attendees.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill").font(LM.Fonts.text(10)).foregroundColor(LM.Colors.textTertiary)
                            Text("\(meeting.attendees.count)").font(LM.Fonts.mono(11)).foregroundColor(LM.Colors.textTertiary)
                        }
                    }
                    if let items = meeting.actionItems, !items.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").font(LM.Fonts.text(10)).foregroundColor(LM.Colors.cyan.opacity(0.7))
                            Text("\(items.count) actions").font(LM.Fonts.mono(11)).foregroundColor(LM.Colors.cyan.opacity(0.7))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(LM.Fonts.text(10, weight: .bold))
                        .foregroundColor(LM.Colors.textGhost)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .background(LM.Colors.surface)
        .cornerRadius(LM.Radius.md)
        .overlay(RoundedRectangle(cornerRadius: LM.Radius.md).stroke(LM.Colors.borderDim, lineWidth: 1))
        .shadow(color: meeting.status.isProcessing ? LM.Colors.cyan.opacity(0.06) : .clear, radius: 12)
    }
}

