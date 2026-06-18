import SwiftUI
import AVFoundation
import MessageUI
import UIKit

struct MeetingDetailView<T: APIServiceProtocol>: View {
    @State var meeting: Meeting
    @ObservedObject var apiService: T
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State private var isSendingEmail = false
    @State private var emailSentConfirmation = false
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isShowingMailCompose = false
    @State private var mailComposeResult: Result<MFMailComposeResult, Error>? = nil

    // Audio
    @StateObject private var audioPlayer = MeetingAudioPlayer()

    // LUMEN Chat
    @StateObject private var lumenService = LUMENService()
    @State private var chatInput = ""
    @State private var chatMessages: [(role: String, text: String)] = []
    @State private var isChatLoading = false
    @State private var showChat = false

    var body: some View {
        ZStack {
            LM.Colors.void.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: LM.Space.md) {

                    // MARK: Header
                    LUMENCard(borderColor: LM.Colors.borderCyan) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(meeting.createdAt, style: .date)
                                        .font(LM.Fonts.text(20, weight: .bold))
                                        .foregroundColor(LM.Colors.textPrimary)
                                    Text(meeting.createdAt, style: .time)
                                        .font(LM.Fonts.mono(12))
                                        .foregroundColor(LM.Colors.textTertiary)
                                }
                                Spacer()
                                LUMENStatusBadge(status: meeting.status)
                            }
                            if meeting.status.isProcessing {
                                HStack(spacing: 8) {
                                    LUMENOrbView(state: .responding, speechService: SpeechRecognizerService.preview, size: 28)
                                    Text("ORA is processing your meeting...")
                                        .font(LM.Fonts.text(12))
                                        .foregroundColor(LM.Colors.textSecondary)
                                }
                            }
                            if let org = meeting.organizerName, !org.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.circle.fill").font(LM.Fonts.text(12)).foregroundColor(LM.Colors.cyan)
                                    Text(org).font(LM.Fonts.text(13)).foregroundColor(LM.Colors.textSecondary)
                                }
                            }
                        }
                    }

                    // MARK: Audio Player
                    LUMENAudioPlayerCard(audioPlayer: audioPlayer, transcript: meeting.transcript)

                    // MARK: Attendees
                    if !meeting.attendees.isEmpty {
                        LUMENCard {
                            VStack(alignment: .leading, spacing: 12) {
                                LUMENSectionHeader(title: "Attendees", icon: "person.2.fill")
                                VStack(spacing: 8) {
                                    ForEach(meeting.attendees) { a in
                                        HStack(spacing: 10) {
                                            ZStack {
                                                Circle().fill(LM.Colors.cyanGlow).frame(width: 34, height: 34)
                                                Text(String(a.name.prefix(1)).uppercased())
                                                    .font(LM.Fonts.rounded(13, weight: .bold))
                                                    .foregroundColor(LM.Colors.cyan)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(a.name).font(LM.Fonts.text(13, weight: .medium)).foregroundColor(LM.Colors.textPrimary)
                                                Text(a.email).font(LM.Fonts.mono(11)).foregroundColor(LM.Colors.textTertiary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Action Items
                    if let items = meeting.actionItems, !items.isEmpty {
                        LUMENCard(borderColor: LM.Colors.green.opacity(0.3), glowColor: LM.Colors.green) {
                            VStack(alignment: .leading, spacing: 12) {
                                LUMENSectionHeader(title: "Action Items", icon: "checkmark.circle.fill", color: LM.Colors.green)
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                                        HStack(alignment: .top, spacing: 10) {
                                            ZStack {
                                                Circle().stroke(LM.Colors.green.opacity(0.4), lineWidth: 1.5).frame(width: 22, height: 22)
                                                Text("\(i+1)").font(LM.Fonts.mono(9, weight: .bold)).foregroundColor(LM.Colors.green)
                                            }
                                            Text(item).font(LM.Fonts.text(13)).foregroundColor(LM.Colors.textSecondary).fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // MARK: LUMEN Insights (live Q&A logged during recording)
                    if !lumenService.insights.isEmpty {
                        LUMENCard(borderColor: LM.Colors.purple.opacity(0.3), glowColor: LM.Colors.purple) {
                            VStack(alignment: .leading, spacing: 12) {
                                LUMENSectionHeader(title: "LUMEN Insights", icon: "sparkles", color: LM.Colors.purple)
                                VStack(spacing: 10) {
                                    ForEach(lumenService.insights) { insight in
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "mic.fill").font(LM.Fonts.text(10)).foregroundColor(LM.Colors.textTertiary)
                                                Text(insight.question).font(LM.Fonts.text(12)).foregroundColor(LM.Colors.textSecondary).italic()
                                            }
                                            HStack(alignment: .top, spacing: 6) {
                                                Image(systemName: "sparkle").font(LM.Fonts.text(10)).foregroundColor(LM.Colors.purple)
                                                Text(insight.answer).font(LM.Fonts.text(13)).foregroundColor(LM.Colors.textPrimary)
                                            }
                                        }
                                        .padding(10)
                                        .background(LM.Colors.deep)
                                        .cornerRadius(LM.Radius.sm)
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Summary
                    if let summary = meeting.summary {
                        LUMENCard {
                            VStack(alignment: .leading, spacing: 12) {
                                LUMENSectionHeader(title: "Summary", icon: "doc.text.fill")
                                Text(summary).font(LM.Fonts.text(13)).foregroundColor(LM.Colors.textSecondary).lineSpacing(5)
                            }
                        }
                    }

                    // MARK: LUMEN Chat
                    if meeting.status == .completed || meeting.status == .sent {
                        LUMENCard(borderColor: LM.Colors.borderCyan) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    LUMENSectionHeader(title: "Ask ORA", icon: "bubble.left.and.bubble.right.fill")
                                    Spacer()
                                    Button(action: { withAnimation { showChat.toggle() } }) {
                                        Image(systemName: showChat ? "chevron.up" : "chevron.down")
                                            .font(LM.Fonts.text(12))
                                            .foregroundColor(LM.Colors.textTertiary)
                                    }
                                }
                                if showChat {
                                    // Chat messages
                                    if !chatMessages.isEmpty {
                                        VStack(spacing: 8) {
                                            ForEach(Array(chatMessages.enumerated()), id: \.offset) { _, msg in
                                                HStack(alignment: .top, spacing: 8) {
                                                    if msg.role == "user" {
                                                        Spacer()
                                                        Text(msg.text)
                                                            .font(LM.Fonts.text(13))
                                                            .foregroundColor(.black)
                                                            .padding(10)
                                                            .background(LM.Colors.cyan)
                                                            .cornerRadius(LM.Radius.sm)
                                                    } else {
                                                        HStack(alignment: .top, spacing: 6) {
                                                            Image(systemName: "sparkle").font(LM.Fonts.text(11)).foregroundColor(LM.Colors.cyan).padding(.top, 2)
                                                            Text(msg.text)
                                                                .font(LM.Fonts.text(13))
                                                                .foregroundColor(LM.Colors.textPrimary)
                                                                .padding(10)
                                                                .background(LM.Colors.elevated)
                                                                .cornerRadius(LM.Radius.sm)
                                                        }
                                                        Spacer()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Input row
                                    HStack(spacing: 8) {
                                        LUMENTextField(placeholder: "Ask anything about this meeting...", text: $chatInput)
                                        Button(action: sendChatMessage) {
                                            ZStack {
                                                Circle().fill(chatInput.isEmpty ? LM.Colors.surface : LM.Colors.cyan).frame(width: 36, height: 36)
                                                if isChatLoading {
                                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black)).scaleEffect(0.7)
                                                } else {
                                                    Image(systemName: "arrow.up").font(LM.Fonts.text(14, weight: .bold)).foregroundColor(chatInput.isEmpty ? LM.Colors.textTertiary : .black)
                                                }
                                            }
                                        }
                                        .disabled(chatInput.isEmpty || isChatLoading)
                                    }

                                    // Suggested questions
                                    if chatMessages.isEmpty {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(["What decisions were made?", "List all action items", "What were the key topics?", "Who said what?"], id: \.self) { q in
                                                    Button(action: { chatInput = q; sendChatMessage() }) {
                                                        Text(q)
                                                            .font(LM.Fonts.text(11))
                                                            .foregroundColor(LM.Colors.cyan)
                                                            .padding(.horizontal, 10)
                                                            .padding(.vertical, 6)
                                                            .background(LM.Colors.cyanGlow)
                                                            .cornerRadius(LM.Radius.pill)
                                                            .overlay(RoundedRectangle(cornerRadius: LM.Radius.pill).stroke(LM.Colors.borderCyan, lineWidth: 1))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // MARK: Transcript
                    if let transcript = meeting.transcript {
                        LUMENCard {
                            VStack(alignment: .leading, spacing: 12) {
                                LUMENSectionHeader(title: "Full Transcript", icon: "text.quote")
                                Text(transcript)
                                    .font(LM.Fonts.text(12))
                                    .foregroundColor(LM.Colors.textTertiary)
                                    .lineSpacing(6)
                            }
                        }
                    }

                    // MARK: Action Buttons
                    if meeting.status == .completed || meeting.status == .sent {
                        VStack(spacing: 10) {
                            LUMENButton(title: "Share Meeting Notes", icon: "square.and.arrow.up", style: .secondary, action: exportMeeting)
                            LUMENButton(
                                title: isSendingEmail ? "Sending..."
                                    : emailSentConfirmation ? "Summary Sent!"
                                    : (meeting.status == .sent ? "Resend Recap Email" : "Send Recap Email"),
                                icon: isSendingEmail ? "paperplane.fill"
                                    : emailSentConfirmation ? "checkmark.circle.fill"
                                    : "envelope.fill",
                                style: emailSentConfirmation ? .secondary : .primary,
                                action: sendEmail
                            )
                            .disabled(isSendingEmail)
                        }
                    }

                    Spacer(minLength: LM.Space.xl)
                }
                .padding(LM.Space.md)
            }
        }
        .navigationTitle("Meeting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingShareSheet) { ShareSheet(items: shareItems) }
        .sheet(isPresented: $isShowingMailCompose) {
            MailComposeView(
                recipients: meeting.attendees.map { $0.email },
                subject: "Meeting Recap · \(meeting.createdAt.formatted(date: .abbreviated, time: .omitted))",
                body: buildEmailBody()
            ) { result in
                isShowingMailCompose = false
                if case .success(let r) = result, r == .sent {
                    emailSentConfirmation = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        await MainActor.run { emailSentConfirmation = false }
                    }
                }
            }
        }
        .onReceive(timer) { _ in if meeting.status.isProcessing { refreshMeeting() } }
        .onAppear {
            if let urlStr = meeting.audioUrl, let url = URL(string: urlStr) { audioPlayer.load(url: url) }
        }
        .onDisappear { audioPlayer.stop() }
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
        // Show iOS share sheet — works with Mail, Gmail, Messages, AirDrop, Copy on every device.
        // No mailto: threading, no callback complexity, no crash.
        let subject = "Meeting Recap - \(meeting.createdAt.formatted(date: .abbreviated, time: .omitted))"
        let body = buildEmailBody()
        shareItems = ["\(subject)\n\n\(body)"]
        isShowingShareSheet = true
    }

    func buildEmailBody() -> String {
        var t = "Meeting Recap — ORA\n"
        t += "Date: \(meeting.createdAt.formatted(date: .long, time: .shortened))\n"
        if let org = meeting.organizerName, !org.isEmpty { t += "Organizer: \(org)\n" }
        t += "\n"
        if let s = meeting.summary { t += "SUMMARY\n\(s)\n\n" }
        if let items = meeting.actionItems, !items.isEmpty {
            t += "ACTION ITEMS\n"
            for (i, item) in items.enumerated() { t += "  \(i+1). \(item)\n" }
            t += "\n"
        }
        if !lumenService.insights.isEmpty {
            t += "ORA INSIGHTS\n"
            for ins in lumenService.insights { t += "Q: \(ins.question)\nA: \(ins.answer)\n\n" }
        }
        if let tr = meeting.transcript { t += "FULL TRANSCRIPT\n\(tr)\n" }
        t += "\n— Sent via ORA · AI Meeting Intelligence"
        return t
    }

    func exportMeeting() {
        var t = "Meeting Notes — ORA\nDate: \(meeting.createdAt)\n\n"
        if let org = meeting.organizerName { t += "Organizer: \(org)\n" }
        if !meeting.attendees.isEmpty { t += "Attendees: \(meeting.attendees.map { $0.name }.joined(separator: ", "))\n" }
        if let s = meeting.summary { t += "\nSUMMARY\n\(s)\n" }
        if let items = meeting.actionItems, !items.isEmpty { t += "\nACTION ITEMS\n"; for (i, item) in items.enumerated() { t += "\(i+1). \(item)\n" } }
        if !lumenService.insights.isEmpty { t += "\nORA INSIGHTS\n"; for ins in lumenService.insights { t += "Q: \(ins.question)\nA: \(ins.answer)\n\n" } }
        if let tr = meeting.transcript { t += "\nFULL TRANSCRIPT\n\(tr)\n" }
        shareItems = [t]
        isShowingShareSheet = true
    }

    func sendChatMessage() {
        let q = chatInput.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        chatInput = ""
        chatMessages.append((role: "user", text: q))
        isChatLoading = true
        Task {
            let context = meeting.transcript ?? meeting.summary ?? ""
            let answer = await lumenService.ask(question: q, context: context)
            await MainActor.run {
                chatMessages.append((role: "ora", text: answer))
                isChatLoading = false
            }
        }
    }
}

// MARK: - LUMEN Audio Player Card
struct LUMENAudioPlayerCard: View {
    @ObservedObject var audioPlayer: MeetingAudioPlayer
    let transcript: String?
    @State private var playbackRate: Float = 1.0
    private let rates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        LUMENCard(borderColor: LM.Colors.borderCyan) {
            VStack(spacing: 14) {
                // Waveform
                HStack(spacing: 3) {
                    ForEach(0..<44, id: \.self) { i in
                        LUMENPlaybackBar(index: i, isPlaying: audioPlayer.isPlaying, progress: audioPlayer.progress)
                    }
                }
                .frame(height: 44)

                // Scrubber
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(LM.Colors.surface).frame(height: 3)
                        Capsule().fill(LM.Colors.cyan).frame(width: max(0, geo.size.width * CGFloat(audioPlayer.progress)), height: 3)
                        Circle().fill(LM.Colors.cyan).frame(width: 12, height: 12)
                            .offset(x: max(0, geo.size.width * CGFloat(audioPlayer.progress) - 6))
                            .shadow(color: LM.Colors.cyan.opacity(0.6), radius: 4)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                        audioPlayer.seek(to: Double(min(max(v.location.x / geo.size.width, 0), 1)))
                    })
                }
                .frame(height: 12)

                // Time + controls
                HStack {
                    Text(audioPlayer.currentTimeString)
                        .font(LM.Fonts.mono(11))
                        .foregroundColor(LM.Colors.textTertiary)
                    Spacer()
                    HStack(spacing: 24) {
                        Button(action: { audioPlayer.skip(-15) }) {
                            Image(systemName: "gobackward.15").font(LM.Fonts.text(18)).foregroundColor(LM.Colors.textSecondary)
                        }
                        Button(action: { audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play() }) {
                            ZStack {
                                Circle().fill(LM.Colors.cyan).frame(width: 52, height: 52)
                                    .shadow(color: LM.Colors.cyan.opacity(0.5), radius: 12)
                                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(LM.Fonts.text(20))
                                    .foregroundColor(.black)
                                    .offset(x: audioPlayer.isPlaying ? 0 : 2)
                            }
                        }
                        Button(action: { audioPlayer.skip(15) }) {
                            Image(systemName: "goforward.15").font(LM.Fonts.text(18)).foregroundColor(LM.Colors.textSecondary)
                        }
                    }
                    Spacer()
                    Text(audioPlayer.durationString)
                        .font(LM.Fonts.mono(11))
                        .foregroundColor(LM.Colors.textTertiary)
                }

                // Speed control
                HStack(spacing: 0) {
                    ForEach(rates, id: \.self) { rate in
                        Button(action: {
                            playbackRate = rate
                            audioPlayer.setRate(rate)
                        }) {
                            Text(rate == 1.0 ? "1x" : "\(rate < 1 ? String(format: "%.2g", rate) : String(format: "%.2gx", rate))")
                                .font(LM.Fonts.mono(10, weight: .bold))
                                .foregroundColor(playbackRate == rate ? .black : LM.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(playbackRate == rate ? LM.Colors.cyan : LM.Colors.deep)
                        }
                    }
                }
                .cornerRadius(LM.Radius.sm)
                .overlay(RoundedRectangle(cornerRadius: LM.Radius.sm).stroke(LM.Colors.borderCyan, lineWidth: 1))
            }
        }
    }
}

// MARK: - Playback Waveform Bar
struct LUMENPlaybackBar: View {
    let index: Int
    let isPlaying: Bool
    let progress: Double
    @State private var animH: CGFloat = 4

    private var base: CGFloat {
        let p: [CGFloat] = [8,18,28,22,12,34,18,26,38,14,32,24,16,40,10,28,20,36,8,18,30,14,38,18,26,12,32,24,10,22,36,16,28,20,34,12,24,30,18,26,10,22,34,16]
        return p[index % p.count]
    }
    private var active: Bool { Double(index) / 44.0 < progress }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(active ? LM.Colors.cyan : LM.Colors.borderDim)
            .frame(width: 3, height: isPlaying && active ? animH : base)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: Double.random(in: 0.4...0.9)).repeatForever(autoreverses: true).delay(Double(index) * 0.02)) {
                    animH = base * CGFloat.random(in: 0.5...1.6)
                }
            }
            .onChange(of: isPlaying) { _, p in
                withAnimation(p ? Animation.easeInOut(duration: Double.random(in: 0.4...0.9)).repeatForever(autoreverses: true) : .easeOut(duration: 0.3)) {
                    animH = p ? base * CGFloat.random(in: 0.5...1.6) : base
                }
            }
    }
}

// MARK: - MeetingAudioPlayer (extended with rate control)
class MeetingAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var currentTimeString = "0:00"
    @Published var durationString = "0:00"
    private var timer: Timer?
    private var rate: Float = 1.0

    func load(url: URL) {
        let local = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(url.lastPathComponent)
        let target = FileManager.default.fileExists(atPath: local.path) ? local : url
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            if let data = try? Data(contentsOf: target), let p = try? AVAudioPlayer(data: data) {
                DispatchQueue.main.async {
                    self.player = p; p.delegate = self; p.enableRate = true; p.prepareToPlay()
                    self.durationString = self.fmt(p.duration)
                }
            }
        }
    }

    func play() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.rate = rate; player?.play(); isPlaying = true; startTimer()
    }
    func pause() { player?.pause(); isPlaying = false; timer?.invalidate() }
    func stop() { player?.stop(); isPlaying = false; timer?.invalidate() }
    func seek(to f: Double) { guard let p = player else { return }; p.currentTime = p.duration * f; update() }
    func skip(_ s: Double) { guard let p = player else { return }; p.currentTime = min(max(p.currentTime + s, 0), p.duration); update() }
    func setRate(_ r: Float) { rate = r; if let p = player { p.rate = r } }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.update() }
    }
    private func update() {
        guard let p = player, p.duration > 0 else { return }
        progress = p.currentTime / p.duration; currentTimeString = fmt(p.currentTime)
    }
    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully f: Bool) {
        isPlaying = false; progress = 0; timer?.invalidate(); currentTimeString = "0:00"
    }
    private func fmt(_ t: TimeInterval) -> String { String(format: "%d:%02d", Int(t)/60, Int(t)%60) }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ u: UIActivityViewController, context: Context) {}
}

// MARK: - Mail Compose (native iOS mail, no backend needed)
struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    let onFinish: (Result<MFMailComposeResult, Error>) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: (Result<MFMailComposeResult, Error>) -> Void
        init(onFinish: @escaping (Result<MFMailComposeResult, Error>) -> Void) { self.onFinish = onFinish }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            if let error = error { onFinish(.failure(error)) }
            else { onFinish(.success(result)) }
            controller.dismiss(animated: true)
        }
    }
}
