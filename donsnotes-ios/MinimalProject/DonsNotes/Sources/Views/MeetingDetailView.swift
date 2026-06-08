import SwiftUI
import AVFoundation

struct MeetingDetailView<T: APIServiceProtocol>: View {
    @State var meeting: Meeting
    @ObservedObject var apiService: T
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State private var isSendingEmail = false
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []
    
    // Audio playback
    @StateObject private var audioPlayer = MeetingAudioPlayer()
    
    var body: some View {
        ZStack {
            DNColors.background.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // MARK: Header Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(meeting.createdAt, style: .date)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(DNColors.textPrimary)
                                Text(meeting.createdAt, style: .time)
                                    .font(.system(size: 14))
                                    .foregroundColor(DNColors.textSecondary)
                            }
                            Spacer()
                            StatusPill(status: meeting.status)
                        }
                        
                        if meeting.status.isProcessing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: DNColors.accent))
                                    .scaleEffect(0.8)
                                Text("Processing your meeting...")
                                    .font(.system(size: 13))
                                    .foregroundColor(DNColors.textSecondary)
                            }
                            .padding(.top, 4)
                        }
                        
                        if let organizer = meeting.organizerName, !organizer.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(DNColors.accent)
                                Text(organizer)
                                    .font(.system(size: 14))
                                    .foregroundColor(DNColors.textSecondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(DNColors.surface)
                    .cornerRadius(16)
                    
                    // MARK: Audio Player
                    if meeting.audioUrl != nil || true {
                        AudioPlayerCard(audioPlayer: audioPlayer, meeting: meeting)
                    }
                    
                    // MARK: Attendees
                    if !meeting.attendees.isEmpty {
                        SectionCard(title: "Attendees", icon: "person.2.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(meeting.attendees) { attendee in
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(DNColors.accent.opacity(0.15))
                                                .frame(width: 36, height: 36)
                                            Text(String(attendee.name.prefix(1)).uppercased())
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(DNColors.accent)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(attendee.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(DNColors.textPrimary)
                                            Text(attendee.email)
                                                .font(.system(size: 12))
                                                .foregroundColor(DNColors.textTertiary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // MARK: Action Items
                    if let items = meeting.actionItems, !items.isEmpty {
                        SectionCard(title: "Action Items", icon: "checkmark.circle.fill", accentColor: DNColors.successGreen) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                                    HStack(alignment: .top, spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .stroke(DNColors.successGreen.opacity(0.4), lineWidth: 1.5)
                                                .frame(width: 22, height: 22)
                                            Text("\(idx + 1)")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(DNColors.successGreen)
                                        }
                                        Text(item)
                                            .font(.system(size: 14))
                                            .foregroundColor(DNColors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    
                    // MARK: Summary
                    if let summary = meeting.summary {
                        SectionCard(title: "Summary", icon: "doc.text.fill") {
                            Text(summary)
                                .font(.system(size: 14))
                                .foregroundColor(DNColors.textSecondary)
                                .lineSpacing(5)
                        }
                    }
                    
                    // MARK: Transcript
                    if let transcript = meeting.transcript {
                        SectionCard(title: "Full Transcript", icon: "text.quote") {
                            Text(transcript)
                                .font(.system(size: 13))
                                .foregroundColor(DNColors.textTertiary)
                                .lineSpacing(6)
                        }
                    }
                    
                    // MARK: Action Buttons
                    VStack(spacing: 12) {
                        if meeting.status == .completed || meeting.status == .sent {
                            Button(action: exportMeeting) {
                                Label("Share Meeting Notes", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(14)
                                    .background(DNColors.surfaceElevated)
                                    .foregroundColor(DNColors.textPrimary)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(DNColors.divider, lineWidth: 1))
                            }
                            
                            Button(action: sendEmail) {
                                Group {
                                    if isSendingEmail {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .frame(maxWidth: .infinity)
                                    } else {
                                        Label(meeting.status == .sent ? "Resend Recap Email" : "Send Recap Email", systemImage: "envelope.fill")
                                            .font(.system(size: 15, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                .padding(14)
                                .background(DNColors.accent)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isSendingEmail)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(16)
            }
        }
        .navigationTitle("Meeting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .onReceive(timer) { _ in
            if meeting.status.isProcessing {
                refreshMeeting()
            }
        }
        .onAppear {
            if let urlStr = meeting.audioUrl, let url = URL(string: urlStr) {
                audioPlayer.load(url: url)
            }
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
    
    func refreshMeeting() {
        Task {
            do {
                let updated = try await apiService.fetchMeetingDetails(id: meeting.id)
                await MainActor.run { self.meeting = updated }
            } catch {}
        }
    }
    
    func sendEmail() {
        isSendingEmail = true
        Task {
            do {
                try await apiService.sendRecapEmail(id: meeting.id)
                refreshMeeting()
                await MainActor.run { isSendingEmail = false }
            } catch {
                await MainActor.run { isSendingEmail = false }
            }
        }
    }
    
    func exportMeeting() {
        var text = "Meeting Notes\n"
        text += "Date: \(meeting.createdAt)\n\n"
        if let organizer = meeting.organizerName { text += "Organizer: \(organizer)\n" }
        if !meeting.attendees.isEmpty {
            text += "Attendees: \(meeting.attendees.map { $0.name }.joined(separator: ", "))\n"
        }
        if let summary = meeting.summary { text += "\nSUMMARY\n\(summary)\n" }
        if let items = meeting.actionItems, !items.isEmpty {
            text += "\nACTION ITEMS\n"
            for (i, item) in items.enumerated() { text += "\(i+1). \(item)\n" }
        }
        if let transcript = meeting.transcript { text += "\nFULL TRANSCRIPT\n\(transcript)\n" }
        shareItems = [text]
        isShowingShareSheet = true
    }
}

// MARK: - Audio Player Card
struct AudioPlayerCard: View {
    @ObservedObject var audioPlayer: MeetingAudioPlayer
    let meeting: Meeting
    
    var body: some View {
        VStack(spacing: 12) {
            // Waveform visualization
            HStack(spacing: 3) {
                ForEach(0..<40, id: \.self) { i in
                    WaveformBar(index: i, isPlaying: audioPlayer.isPlaying, progress: audioPlayer.progress)
                }
            }
            .frame(height: 48)
            .padding(.horizontal, 8)
            
            // Scrubber
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 3)
                    Capsule()
                        .fill(DNColors.accent)
                        .frame(width: geo.size.width * CGFloat(audioPlayer.progress), height: 3)
                }
                .frame(height: 3)
                .contentShape(Rectangle().size(CGSize(width: geo.size.width, height: 28)).offset(y: -12))
                .gesture(DragGesture(minimumDistance: 0).onChanged { val in
                    let p = min(max(val.location.x / geo.size.width, 0), 1)
                    audioPlayer.seek(to: Double(p))
                })
            }
            .frame(height: 3)
            .padding(.horizontal, 8)
            
            // Time + Controls
            HStack {
                Text(audioPlayer.currentTimeString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(DNColors.textTertiary)
                Spacer()
                
                HStack(spacing: 28) {
                    Button(action: { audioPlayer.skip(-15) }) {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 20))
                            .foregroundColor(DNColors.textSecondary)
                    }
                    Button(action: { audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play() }) {
                        ZStack {
                            Circle()
                                .fill(DNColors.accent)
                                .frame(width: 52, height: 52)
                                .shadow(color: DNColors.accent.opacity(0.4), radius: 12, x: 0, y: 4)
                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .offset(x: audioPlayer.isPlaying ? 0 : 2)
                        }
                    }
                    Button(action: { audioPlayer.skip(15) }) {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 20))
                            .foregroundColor(DNColors.textSecondary)
                    }
                }
                
                Spacer()
                Text(audioPlayer.durationString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(DNColors.textTertiary)
            }
            .padding(.horizontal, 8)
        }
        .padding(16)
        .background(DNColors.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(DNColors.accent.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Waveform Bar
struct WaveformBar: View {
    let index: Int
    let isPlaying: Bool
    let progress: Double
    
    @State private var animHeight: CGFloat = 4
    
    private var baseHeight: CGFloat {
        let pattern: [CGFloat] = [8, 18, 28, 20, 10, 32, 16, 24, 36, 12,
                                   30, 22, 14, 38, 10, 26, 20, 34, 8, 18,
                                   28, 12, 36, 16, 24, 10, 30, 22, 8, 20,
                                   34, 14, 26, 18, 32, 10, 22, 28, 16, 24]
        return pattern[index % pattern.count]
    }
    
    private var isActive: Bool {
        Double(index) / 40.0 < progress
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(isActive ? DNColors.accent : Color.white.opacity(0.15))
            .frame(width: 3, height: isPlaying && isActive ? animHeight : baseHeight)
            .onAppear {
                if isPlaying {
                    withAnimation(Animation.easeInOut(duration: Double.random(in: 0.4...0.8)).repeatForever(autoreverses: true).delay(Double(index) * 0.03)) {
                        animHeight = baseHeight * CGFloat.random(in: 0.5...1.5)
                    }
                }
            }
            .onChange(of: isPlaying, perform: { playing in
                if playing {
                    withAnimation(Animation.easeInOut(duration: Double.random(in: 0.4...0.8)).repeatForever(autoreverses: true)) {
                        animHeight = baseHeight * CGFloat.random(in: 0.5...1.5)
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        animHeight = baseHeight
                    }
                }
            })
    }
}

// MARK: - Section Card
struct SectionCard<Content: View>: View {
    let title: String
    let icon: String
    var accentColor: Color = DNColors.accent
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(accentColor)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accentColor)
                    .tracking(1.2)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DNColors.surface)
        .cornerRadius(16)
    }
}

// MARK: - Audio Player ViewModel
class MeetingAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTimeString = "0:00"
    @Published var durationString = "0:00"
    
    private var timer: Timer?
    
    func load(url: URL) {
        // Try to load the audio file from local documents first
        let localURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(url.lastPathComponent)
        let targetURL = FileManager.default.fileExists(atPath: localURL.path) ? localURL : url
        
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            if let data = try? Data(contentsOf: targetURL),
               let player = try? AVAudioPlayer(data: data) {
                DispatchQueue.main.async {
                    self.player = player
                    player.delegate = self
                    player.prepareToPlay()
                    self.durationString = self.formatTime(player.duration)
                }
            }
        }
    }
    
    func play() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
    }
    
    func stop() {
        player?.stop()
        isPlaying = false
        timer?.invalidate()
    }
    
    func seek(to fraction: Double) {
        guard let player = player else { return }
        player.currentTime = player.duration * fraction
        updateProgress()
    }
    
    func skip(_ seconds: Double) {
        guard let player = player else { return }
        player.currentTime = min(max(player.currentTime + seconds, 0), player.duration)
        updateProgress()
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func updateProgress() {
        guard let player = player, player.duration > 0 else { return }
        progress = player.currentTime / player.duration
        currentTimeString = formatTime(player.currentTime)
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        progress = 0
        timer?.invalidate()
        currentTimeString = "0:00"
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
