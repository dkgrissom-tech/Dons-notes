import SwiftUI
import AVFoundation

struct RecordingView<T: APIServiceProtocol>: View {
    @StateObject var recorder = AudioRecorder()
    @ObservedObject var apiService: T
    @ObservedObject var contactService = ContactService.shared
    @ObservedObject var profileService = ProfileService.shared
    @StateObject var speechService = SpeechRecognizerService()
    @StateObject var lumen = LUMENService()
    @State private var attendees: [Attendee] = []
    @State private var newAttendeeEmail = ""
    @State private var newAttendeeName = ""
    @State private var isUploading = false
    @State private var elapsedSeconds = 0
    @State private var recordingTimer: Timer? = nil
    @Environment(\.dismiss) var dismiss

    private var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        NavigationView {
            ZStack {
                LM.Colors.void.ignoresSafeArea()

                if !recorder.isRecording && recorder.recordingURL == nil {
                    setupSection
                } else {
                    recordingSection
                }

                // LUMEN response overlay
                if lumen.isShowingResponse {
                    VStack {
                        Spacer()
                        LUMENResponseOverlay(
                            question: lumen.currentQuestion,
                            answer: lumen.currentAnswer,
                            isVisible: lumen.isShowingResponse,
                            onDismiss: { lumen.dismissResponse() }
                        )
                        .padding(.bottom, 100)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.3), value: lumen.isShowingResponse)
                }
            }
            .navigationTitle(recorder.isRecording ? "" : "New Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !recorder.isRecording {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(LM.Colors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if recorder.isRecording {
                        // Voice toggle button
                        Button(action: { lumen.setVoiceEnabled(!lumen.isVoiceEnabled) }) {
                            HStack(spacing: 4) {
                                Image(systemName: lumen.isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                    .font(LM.Fonts.text(13))
                                Text(lumen.isVoiceEnabled ? "Voice" : "Silent")
                                    .font(LM.Fonts.mono(11, weight: .bold))
                            }
                            .foregroundColor(lumen.isVoiceEnabled ? LM.Colors.cyan : LM.Colors.textTertiary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(lumen.isVoiceEnabled ? LM.Colors.cyanGlow : LM.Colors.surface)
                            .cornerRadius(LM.Radius.pill)
                            .overlay(RoundedRectangle(cornerRadius: LM.Radius.pill).stroke(lumen.isVoiceEnabled ? LM.Colors.borderCyan : LM.Colors.borderDim, lineWidth: 1))
                        }
                    }
                }
            }
            .onAppear {
                Task { await contactService.syncContacts(from: apiService) }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Setup Section
    private var setupSection: some View {
        ScrollView {
            VStack(spacing: LM.Space.lg) {

                // LUMEN header
                VStack(spacing: 10) {
                    LUMENOrbView(state: .idle, recorder: AudioRecorder(), size: 100)
                    Text("NEW MEETING")
                        .font(LM.Fonts.mono(13, weight: .bold))
                        .foregroundColor(LM.Colors.cyan)
                        .tracking(3)
                    if !profileService.userName.isEmpty {
                        Text("Organizer: \(profileService.userName)")
                            .font(LM.Fonts.text(13))
                            .foregroundColor(LM.Colors.textSecondary)
                    }
                }
                .padding(.top, LM.Space.md)

                // Quick add contacts
                if !contactService.savedContacts.isEmpty {
                    VStack(alignment: .leading, spacing: LM.Space.sm) {
                        LUMENSectionHeader(title: "Quick Add", icon: "person.fill.badge.plus")
                            .padding(.horizontal, LM.Space.md)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(contactService.savedContacts) { contact in
                                    Button(action: { toggleAttendee(contact) }) {
                                        let sel = attendees.contains(where: { $0.email == contact.email })
                                        VStack(spacing: 6) {
                                            ZStack {
                                                Circle()
                                                    .fill(sel ? LM.Colors.cyan : LM.Colors.surface)
                                                    .frame(width: 48, height: 48)
                                                    .shadow(color: sel ? LM.Colors.cyan.opacity(0.4) : .clear, radius: 8)
                                                Text(String(contact.name.prefix(1)).uppercased())
                                                    .font(LM.Fonts.rounded(18, weight: .bold))
                                                    .foregroundColor(sel ? .black : LM.Colors.textSecondary)
                                            }
                                            Text(contact.name.components(separatedBy: " ").first ?? contact.name)
                                                .font(LM.Fonts.text(10))
                                                .foregroundColor(sel ? LM.Colors.cyan : LM.Colors.textTertiary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 68)
                                    }
                                }
                            }
                            .padding(.horizontal, LM.Space.md)
                        }
                    }
                }

                // Add attendee
                VStack(alignment: .leading, spacing: LM.Space.sm) {
                    LUMENSectionHeader(title: "Add Attendee", icon: "person.badge.plus")
                        .padding(.horizontal, LM.Space.md)
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            LUMENTextField(placeholder: "Name", text: $newAttendeeName, icon: "person", contentType: .name, keyboard: .default)
                            LUMENTextField(placeholder: "Email", text: $newAttendeeEmail, icon: "envelope", contentType: .emailAddress, keyboard: .emailAddress)
                        }
                        .padding(.horizontal, LM.Space.md)
                        HStack(spacing: 10) {
                            LUMENButton(title: "Add", icon: "plus", style: (newAttendeeEmail.isEmpty || newAttendeeName.isEmpty) ? .ghost : .primary, action: addAttendee)
                                .disabled(newAttendeeEmail.isEmpty || newAttendeeName.isEmpty)
                            LUMENButton(title: speechService.isListening ? "Listening..." : "Dictate", icon: speechService.isListening ? "mic.fill" : "mic", style: speechService.isListening ? .danger : .secondary, action: toggleListening)
                        }
                        .padding(.horizontal, LM.Space.md)
                    }
                }

                // Attendees list
                if !attendees.isEmpty {
                    VStack(alignment: .leading, spacing: LM.Space.sm) {
                        LUMENSectionHeader(title: "Attendees (\(attendees.count))", icon: "person.2.fill")
                            .padding(.horizontal, LM.Space.md)
                        VStack(spacing: 2) {
                            ForEach(attendees) { attendee in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle().fill(LM.Colors.cyanGlow).frame(width: 36, height: 36)
                                        Text(String(attendee.name.prefix(1)).uppercased())
                                            .font(LM.Fonts.rounded(13, weight: .bold))
                                            .foregroundColor(LM.Colors.cyan)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(attendee.name).font(LM.Fonts.text(14, weight: .medium)).foregroundColor(LM.Colors.textPrimary)
                                        Text(attendee.email).font(LM.Fonts.mono(11)).foregroundColor(LM.Colors.textTertiary)
                                    }
                                    Spacer()
                                    Button(action: { attendees.removeAll(where: { $0.email == attendee.email }) }) {
                                        Image(systemName: "xmark.circle.fill").foregroundColor(LM.Colors.textTertiary).font(LM.Fonts.text(16))
                                    }
                                }
                                .padding(.horizontal, LM.Space.md)
                                .padding(.vertical, 10)
                                .background(LM.Colors.surface)
                            }
                        }
                        .cornerRadius(LM.Radius.md)
                        .overlay(RoundedRectangle(cornerRadius: LM.Radius.md).stroke(LM.Colors.borderDim, lineWidth: 1))
                        .padding(.horizontal, LM.Space.md)
                    }
                }

                Spacer(minLength: 20)

                // LUMEN tip
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").font(LM.Fonts.text(12)).foregroundColor(LM.Colors.cyan)
                    Text("Say \"Hey Lumen\" during the meeting to ask AI a question")
                        .font(LM.Fonts.text(12))
                        .foregroundColor(LM.Colors.textTertiary)
                }
                .padding(.horizontal, LM.Space.lg)
                .multilineTextAlignment(.center)

                // Start button
                LUMENButton(title: "Start Recording", icon: "mic.fill", style: .primary) {
                    startRecording()
                }
                .padding(.horizontal, LM.Space.md)
                .padding(.bottom, LM.Space.xl)
            }
        }
        .onChange(of: speechService.transcript) { _, v in parseTranscript(v) }
    }

    // MARK: - Recording Section
    private var recordingSection: some View {
        ZStack {
            // Background grid lines for HUD effect
            GeometryReader { geo in
                Path { p in
                    let spacing: CGFloat = 40
                    var x: CGFloat = 0
                    while x < geo.size.width {
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: geo.size.height))
                        x += spacing
                    }
                    var y: CGFloat = 0
                    while y < geo.size.height {
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        y += spacing
                    }
                }
                .stroke(LM.Colors.cyan.opacity(0.04), lineWidth: 0.5)
            }
            .ignoresSafeArea()

            if recorder.isRecording {
                VStack(spacing: 0) {
                    Spacer()

                    // Timer
                    Text(elapsedFormatted)
                        .font(LM.Fonts.mono(42, weight: .bold))
                        .foregroundColor(LM.Colors.textPrimary)
                        .padding(.bottom, 8)

                    Text("REC")
                        .font(LM.Fonts.mono(11, weight: .bold))
                        .foregroundColor(LM.Colors.red)
                        .tracking(4)
                        .padding(.bottom, LM.Space.xl)

                    // LUMEN Orb — center stage
                    // recorder passed as @ObservedObject so orb owns the audioLevel subscription
                    LUMENOrbView(
                        state: lumen.orbState,
                        recorder: recorder,
                        size: 180
                    )
                    .onReceive(speechService.$transcript) { t in
                        lumen.processTranscript(t, fullContext: t)
                    }

                    // Waveform — recorder passed directly for live amplitude
                    LUMENWaveformView(recorder: recorder)
                        .padding(.horizontal, LM.Space.xl)
                        .padding(.top, LM.Space.lg)

                    Spacer()

                    // Attendees row
                    if !attendees.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(attendees) { a in
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle().fill(LM.Colors.cyanGlow).frame(width: 32, height: 32)
                                            Text(String(a.name.prefix(1)).uppercased())
                                                .font(LM.Fonts.rounded(12, weight: .bold))
                                                .foregroundColor(LM.Colors.cyan)
                                        }
                                        Text(a.name.components(separatedBy: " ").first ?? a.name)
                                            .font(LM.Fonts.text(9))
                                            .foregroundColor(LM.Colors.textTertiary)
                                    }
                                }
                            }
                            .padding(.horizontal, LM.Space.md)
                        }
                        .padding(.bottom, LM.Space.md)
                    }

                    // Stop button
                    LUMENButton(title: "Stop Recording", icon: "stop.fill", style: .danger) {
                        stopRecording()
                    }
                    .padding(.horizontal, LM.Space.md)
                    .padding(.bottom, LM.Space.xl)
                }

            } else if let url = recorder.recordingURL {
                // Upload section
                VStack(spacing: LM.Space.lg) {
                    Spacer()
                    LUMENOrbView(state: .idle, recorder: AudioRecorder(), size: 120)

                    Text("RECORDING COMPLETE")
                        .font(LM.Fonts.mono(13, weight: .bold))
                        .foregroundColor(LM.Colors.green)
                        .tracking(2)

                    Text("\(attendees.count) attendee\(attendees.count == 1 ? "" : "s") will receive the recap")
                        .font(LM.Fonts.text(14))
                        .foregroundColor(LM.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, LM.Space.xl)

                    Spacer()

                    LUMENButton(title: isUploading ? "Uploading..." : "Upload & Process", icon: isUploading ? nil : "arrow.up.circle.fill", style: .primary) {
                        uploadMeeting(url: url)
                    }
                    .disabled(isUploading)
                    .padding(.horizontal, LM.Space.md)

                    Button("Discard Recording") { recorder.recordingURL = nil }
                        .font(LM.Fonts.text(13))
                        .foregroundColor(LM.Colors.red.opacity(0.7))
                        .padding(.bottom, LM.Space.xl)
                }
            }
        }
    }

    // MARK: - Helpers
    func startRecording() {
        recorder.startRecording()
        speechService.startListening()
        lumen.reset()
        elapsedSeconds = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
            lumen.checkTriggerTimeout()
        }
    }

    func stopRecording() {
        recorder.stopRecording()
        speechService.stopListening()
        recordingTimer?.invalidate()
        recordingTimer = nil
    }

    func addAttendee() {
        guard !newAttendeeEmail.isEmpty, !newAttendeeName.isEmpty else { return }
        let a = Attendee(email: newAttendeeEmail, name: newAttendeeName)
        if !attendees.contains(where: { $0.email == a.email }) {
            attendees.append(a)
            contactService.saveContact(a, via: apiService)
        }
        newAttendeeEmail = ""
        newAttendeeName = ""
    }

    func toggleAttendee(_ contact: Attendee) {
        if let i = attendees.firstIndex(where: { $0.email == contact.email }) { attendees.remove(at: i) }
        else { attendees.append(contact) }
    }

    func toggleListening() {
        if speechService.isListening { speechService.stopListening() } else { speechService.startListening() }
    }

    func parseTranscript(_ text: String) {
        // Split on whitespace, strip punctuation that speech recognition adds
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokens = raw.components(separatedBy: .whitespaces).map {
            $0.trimmingCharacters(in: CharacterSet.punctuationCharacters)
        }.filter { !$0.isEmpty }

        var detectedEmail: String? = nil
        var nameParts: [String] = []

        for token in tokens {
            // An email token contains @ and a dot after the @
            let lower = token.lowercased()
            if lower.contains("@") && lower.contains(".") {
                detectedEmail = lower
            } else {
                // Only add to name if it doesn't look like a domain fragment
                if !lower.hasPrefix("@") && !lower.hasSuffix(".com") && !lower.hasSuffix(".net") {
                    nameParts.append(token)
                }
            }
        }

        // Only update fields when we have clear signal — don't overwrite what user typed
        if let email = detectedEmail, newAttendeeEmail.isEmpty {
            newAttendeeEmail = email
        }
        if !nameParts.isEmpty, newAttendeeName.isEmpty {
            // Take first 3 tokens max as name (avoid dumping whole transcript)
            newAttendeeName = nameParts.prefix(3).joined(separator: " ")
        }
    }

    func uploadMeeting(url: URL) {
        isUploading = true
        Task {
            do {
                _ = try await apiService.uploadMeeting(audioURL: url, attendees: attendees, organizerName: profileService.userName)
                await MainActor.run { isUploading = false; dismiss() }
            } catch {
                await MainActor.run { isUploading = false }
            }
        }
    }
}

// LUMENWaveBar and LUMENWaveformView are defined in LUMENOrbView.swift
