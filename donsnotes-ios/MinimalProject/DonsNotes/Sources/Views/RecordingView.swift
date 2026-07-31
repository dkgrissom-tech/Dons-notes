import SwiftUI
import Speech
import AVFoundation
import MessageUI
import CoreTelephony

// Architecture:
//   - SpeechRecognizerService is the SOLE owner of the audio session/engine while recording.
//   - AudioRecorder is NOT used for recording (its second driver was the conflict bug).
//   - The SAME speechService instance drives both recognition and the live orb/waveform.
//   - Attendee voice entry uses a separate one-shot SFSpeechRecognizer (AttendeeVoiceInput),
//     which only runs while NOT recording, so it never competes with the recording engine.

struct RecordingView<T: APIServiceProtocol>: View {
    @ObservedObject var apiService: T
    var preloadedAttendees: [Attendee] = []          // pre-populate from a past meeting
    @ObservedObject var contactService = ContactService.shared
    @ObservedObject var profileService = ProfileService.shared
    @StateObject var speechService = SpeechRecognizerService()
    @StateObject var lumen = LUMENService()
    @StateObject private var voiceInput = AttendeeVoiceInput()      // name field mic
    @StateObject private var emailVoiceInput = AttendeeVoiceInput() // email field mic
    @State private var attendees: [Attendee] = []
    @State private var newAttendeeEmail = ""
    @State private var newAttendeeName = ""
    @State private var isUploading = false
    @State private var elapsedSeconds = 0
    @State private var recordingTimer: Timer? = nil
    @State private var flushTimer: Timer? = nil                          // Build 90: auto-flush transcript every 30s
    @State private var recordingStartedAt: Date? = nil                   // Build 100: real start time — embedded in recovery file
    @State private var interruptionObserver: NSObjectProtocol? = nil     // Build 90: phone-call/AirPods/sleep handler
    @State private var resumeAfterInterruption: Bool = false             // Build 90: track if we paused due to interruption
    @State private var callCenter: CTCallCenter? = nil          // Build 91: cellular call monitor
    @State private var phoneCallBannerVisible: Bool = false     // Build 91: banner shown during call
    // Build 100: recording-health alarm state — fires when audio engine dies silently
    @State private var recordingHealthAlarm: Bool = false
    @State private var autoResumeTask: Task<Void, Never>? = nil     // Build 101: background retry while banner is up
    @State private var copyLogFeedback: Bool = false                // Build 103: transient "copied" state on log button
    @State private var diagnosticSheetVisible: Bool = false         // Build 103: long-press-orb log viewer
    @State private var recordingHaltReason: String = ""
    @State private var resumeRetryCount: Int = 0
    @State private var deadEngineTicks: Int = 0
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var emailFieldFocused: Bool
    @Environment(\.dismiss) var dismiss

    // Build 96: Pre-meeting brief
    @State private var preMeetingBrief: Meeting? = nil
    @State private var briefExpanded: Bool = false

    private var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        NavigationView {
            ZStack {
                LM.Colors.void.ignoresSafeArea()

                if speechService.isListening {
                    recordingSection
                } else if speechService.recordingURL != nil {
                    uploadSection
                } else {
                    setupSection
                }

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
            .navigationTitle(speechService.isListening ? "" : "New Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !speechService.isListening {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(LM.Colors.textSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if speechService.isListening {
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
                            .overlay(RoundedRectangle(cornerRadius: LM.Radius.pill)
                                .stroke(lumen.isVoiceEnabled ? LM.Colors.borderCyan : LM.Colors.borderDim, lineWidth: 1))
                        }
                    }
                }
            }
            .onAppear {
                Task { await contactService.syncContacts(from: apiService) }
                // Seed attendees from a repeated meeting — only if not already populated
                if attendees.isEmpty && !preloadedAttendees.isEmpty {
                    attendees = preloadedAttendees
                    updatePreMeetingBrief() // Build 96: show brief for preloaded attendees
                }
            }
            // Transcript observer on the stable OUTER view. The full cumulative transcript
            // is passed both as the trigger source and as the Claude context.
            .onReceive(speechService.$transcript) { transcript in
                // No isListening guard — transcript arrives before isListening flips true
                // and we only want to process when the recording HUD is active.
                guard !transcript.isEmpty else { return }
                lumen.processTranscript(transcript, fullContext: transcript)
            }
            // Push dictated attendee text into the name field as it arrives.
            .onChange(of: voiceInput.dictatedText) { _, newValue in
                guard !newValue.isEmpty else { return }
                newAttendeeName = newValue
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    emailFieldFocused = true
                }
            }
            .onChange(of: emailVoiceInput.dictatedText) { _, newValue in
                guard !newValue.isEmpty else { return }
                // Strip spaces — email addresses have none
                newAttendeeEmail = newValue.replacingOccurrences(of: " ", with: "").lowercased()
            }
        }
        .preferredColorScheme(.dark)
        // Paywall: shown when free user taps orb and tries to use LUMEN AI
        .sheet(isPresented: $lumen.isShowingPaywall) {
            PlansView()
        }
        // Build 103: diagnostic log viewer — opened by long-pressing the orb 3s.
        .sheet(isPresented: $diagnosticSheetVisible) {
            DiagnosticLogSheet(isPresented: $diagnosticSheetVisible)
        }
    }

    // MARK: - Setup Screen
    private var setupSection: some View {
        ScrollView {
            VStack(spacing: LM.Space.lg) {
                VStack(spacing: 10) {
                    LUMENOrbView(state: .idle, speechService: speechService, size: 100)
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

                VStack(alignment: .leading, spacing: LM.Space.sm) {
                    LUMENSectionHeader(title: "Add Attendee", icon: "person.badge.plus")
                        .padding(.horizontal, LM.Space.md)
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            LUMENTextField(
                                placeholder: "Name",
                                text: $newAttendeeName,
                                icon: "person",
                                contentType: .name,
                                keyboard: .default,
                                submitLabel: .next,
                                onSubmit: { emailFieldFocused = true }
                            )
                            .focused($nameFieldFocused)
                            // Voice dictation for the name — short one-shot, separate recognizer.
                            Button(action: toggleVoiceDictation) {
                                Image(systemName: voiceInput.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                                    .font(LM.Fonts.text(26))
                                    .foregroundColor(voiceInput.isRecording ? LM.Colors.green : LM.Colors.cyan)
                                    .symbolEffect(.pulse, isActive: voiceInput.isRecording)
                            }
                        }
                        .padding(.horizontal, LM.Space.md)
                        HStack(spacing: 8) {
                            LUMENTextField(
                                placeholder: "Email",
                                text: $newAttendeeEmail,
                                icon: "envelope",
                                contentType: .emailAddress,
                                keyboard: .emailAddress,
                                submitLabel: .done,
                                onSubmit: { addAttendee() }
                            )
                            .focused($emailFieldFocused)
                            Button(action: {
                                if emailVoiceInput.isRecording { emailVoiceInput.stop() }
                                else { emailVoiceInput.start(seconds: 5) }
                            }) {
                                Image(systemName: emailVoiceInput.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                                    .font(LM.Fonts.text(26))
                                    .foregroundColor(emailVoiceInput.isRecording ? LM.Colors.green : LM.Colors.cyan)
                                    .symbolEffect(.pulse, isActive: emailVoiceInput.isRecording)
                            }
                        }
                        .padding(.horizontal, LM.Space.md)
                        HStack(spacing: 10) {
                            LUMENButton(title: "Add", icon: "plus",
                                        style: (newAttendeeEmail.isEmpty || newAttendeeName.isEmpty) ? .ghost : .primary,
                                        action: addAttendee)
                            .disabled(newAttendeeEmail.isEmpty || newAttendeeName.isEmpty)
                        }
                        .padding(.horizontal, LM.Space.md)
                    }
                }

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

                // Build 96: Pre-meeting brief
                if let brief = preMeetingBrief {
                    preMeetingBriefCard(brief)
                        .padding(.horizontal, LM.Space.md)
                        .transition(.opacity)
                }

                HStack(spacing: 8) {
                    Image(systemName: "sparkles").font(LM.Fonts.text(12)).foregroundColor(LM.Colors.cyan)
                    Text("Say \"Ora\" during the meeting to ask AI a question")
                        .font(LM.Fonts.text(12))
                        .foregroundColor(LM.Colors.textTertiary)
                }
                .padding(.horizontal, LM.Space.lg)
                .multilineTextAlignment(.center)

                LUMENButton(title: "Start Recording", icon: "mic.fill", style: .primary) {
                    startRecording()
                }
                .padding(.horizontal, LM.Space.md)
                .padding(.bottom, LM.Space.xl)
            }
        }
    }

    // MARK: - Recording HUD
    private var recordingSection: some View {
        ZStack {
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

            VStack(spacing: 0) {
                Spacer()

                Text(elapsedFormatted)
                    .font(LM.Fonts.mono(42, weight: .bold))
                    .foregroundColor(LM.Colors.textPrimary)
                    .padding(.bottom, 8)

                Text("REC")
                    .font(LM.Fonts.mono(11, weight: .bold))
                    .foregroundColor(LM.Colors.red)
                    .tracking(4)
                    .padding(.bottom, LM.Space.xl)

                // Live orb — tap to wake LUMEN AI, long-press to open diagnostics.
                LUMENOrbView(
                    state: lumen.orbState,
                    speechService: speechService,
                    size: 180
                )
                .onTapGesture {
                    lumen.orbTapped(currentTranscript: speechService.transcript)
                }
                .onLongPressGesture(minimumDuration: 3.0) {
                    // Build 103: hidden gesture — open the diagnostic log viewer.
                    RecordingDiagnostics.shared.log(.ui, "long-press orb → open diagnostic sheet")
                    diagnosticSheetVisible = true
                }

                // Tap hint label
                Text(lumen.isAwake ? "Listening for your question..." : lumen.orbState == .responding ? "ORA is speaking..." : "Tap orb to ask ORA")
                    .font(LM.Fonts.mono(10, weight: .bold))
                    .foregroundColor(lumen.isAwake ? LM.Colors.green.opacity(0.9) : lumen.orbState == .responding ? LM.Colors.cyan.opacity(0.9) : LM.Colors.textTertiary.opacity(0.6))
                    .tracking(1)
                    .padding(.top, 4)

                // Stop button — visible only while Ora is speaking
                if lumen.orbState == .responding {
                    Button(action: { lumen.stopSpeaking() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                                .font(LM.Fonts.text(11))
                            Text("STOP")
                                .font(LM.Fonts.mono(11, weight: .bold))
                                .tracking(2)
                        }
                        .foregroundColor(LM.Colors.red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(LM.Colors.red.opacity(0.12))
                        .cornerRadius(LM.Radius.pill)
                        .overlay(RoundedRectangle(cornerRadius: LM.Radius.pill).stroke(LM.Colors.red.opacity(0.4), lineWidth: 1))
                    }
                    .padding(.top, 8)
                }

                LUMENWaveformView(speechService: speechService)
                    .padding(.horizontal, LM.Space.xl)
                    .padding(.top, LM.Space.lg)

                // Live transcript — lets you confirm the mic is hearing you
                // and see exactly what words are being captured.
                ScrollView {
                    Text(speechService.transcript.isEmpty ? "Listening..." : speechService.transcript)
                        .font(LM.Fonts.mono(11))
                        .foregroundColor(speechService.transcript.isEmpty
                            ? LM.Colors.textTertiary.opacity(0.5)
                            : LM.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, LM.Space.md)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 52)
                .padding(.top, LM.Space.sm)



                Spacer()

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

                LUMENButton(title: "Stop Recording", icon: "stop.fill", style: .danger) {
                    stopRecording()
                }
                .padding(.horizontal, LM.Space.md)
                .padding(.bottom, LM.Space.xl)
            }

            // Build 91: Phone call banner — floats above recording HUD when a
            // cellular call is active. Slides in from top, auto-dismisses on call end.
            if phoneCallBannerVisible {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "phone.fill")
                            .font(LM.Fonts.text(14))
                            .foregroundColor(LM.Colors.textPrimary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recording paused — phone call active")
                                .font(LM.Fonts.mono(11, weight: .bold))
                                .foregroundColor(LM.Colors.textPrimary)
                                .tracking(0.5)
                            Text("Ora will resume automatically when your call ends")
                                .font(LM.Fonts.text(11))
                                .foregroundColor(LM.Colors.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, LM.Space.md)
                    .padding(.vertical, 12)
                    .background(LM.Colors.surface)
                    .cornerRadius(LM.Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: LM.Radius.md)
                            .stroke(LM.Colors.borderDim, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    .padding(.horizontal, LM.Space.md)
                    .padding(.top, LM.Space.md)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(duration: 0.35), value: phoneCallBannerVisible)
            }

            // Build 100: RED alarm banner — shown when audio capture dies silently.
            // Never lets the user think recording is still working. Save button hands
            // whatever transcript was captured off to the recap flow immediately.
            if recordingHealthAlarm {
                VStack {
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(LM.Fonts.text(16))
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("RECORDING STOPPED")
                                    .font(LM.Fonts.mono(11, weight: .bold))
                                    .foregroundColor(.white)
                                    .tracking(0.8)
                                Text(recordingHaltReason)
                                    .font(LM.Fonts.text(11))
                                    .foregroundColor(.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            // Build 101: spinner while background auto-resume is running,
                            // so the user sees Ora is actively trying to recover.
                            if autoResumeTask != nil {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            }
                        }
                        HStack(spacing: 10) {
                            Button {
                                // Save what we have — route through stopRecording so the
                                // partial transcript flows into uploadMeeting and the
                                // audio file gets closed cleanly. stopRecording() sets
                                // speechService.recordingURL to the finalized m4a, which
                                // uploadMeeting needs as its input.
                                RecordingDiagnostics.shared.log(.ui, "SAVE WHAT'S CAPTURED tapped")
                                cancelAutoResumeLoop()
                                recordingHealthAlarm = false
                                stopRecording()
                                if let url = speechService.recordingURL {
                                    uploadMeeting(url: url)
                                }
                            } label: {
                                Text("SAVE WHAT'S CAPTURED")
                                    .font(LM.Fonts.mono(11, weight: .bold))
                                    .foregroundColor(Color.red)
                                    .tracking(0.5)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .cornerRadius(LM.Radius.sm)
                            }
                            Button {
                                // Manual retry — hard-restart the audio engine.
                                // Build 101: use forceRestart so we bypass the zombie
                                // isListening=true state that makes startListening a no-op.
                                RecordingDiagnostics.shared.log(.ui, "RETRY button tapped")
                                cancelAutoResumeLoop()
                                recordingHealthAlarm = false
                                deadEngineTicks = 0
                                speechService.forceRestart(resume: true)
                                lumen.orbState = .listening
                            } label: {
                                Text("RETRY")
                                    .font(LM.Fonts.mono(11, weight: .bold))
                                    .foregroundColor(.white)
                                    .tracking(0.5)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(LM.Radius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: LM.Radius.sm)
                                            .stroke(Color.white, lineWidth: 1)
                                    )
                            }
                        }
                        // Build 103: COPY LOG button — dumps the diagnostic log to
                        // clipboard so the user can paste it into Notes / email /
                        // Messages and send it back to us for post-mortem analysis.
                        Button {
                            RecordingDiagnostics.shared.log(.ui, "COPY LOG tapped")
                            let text = RecordingDiagnostics.shared.exportText()
                            UIPasteboard.general.string = text
                            copyLogFeedback = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                copyLogFeedback = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: copyLogFeedback ? "checkmark" : "doc.on.clipboard")
                                    .font(LM.Fonts.text(11))
                                Text(copyLogFeedback ? "COPIED — PASTE INTO A MESSAGE" : "COPY DIAGNOSTIC LOG")
                                    .font(LM.Fonts.mono(10, weight: .bold))
                                    .tracking(0.5)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(LM.Radius.sm)
                        }
                    }
                    .padding(.horizontal, LM.Space.md)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .cornerRadius(LM.Radius.md)
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                    .padding(.horizontal, LM.Space.md)
                    .padding(.top, LM.Space.md)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(duration: 0.35), value: recordingHealthAlarm)
                .zIndex(1000)  // Always on top.
            }
        }
    }

    // MARK: - Upload Screen
    private var uploadSection: some View {
        VStack(spacing: LM.Space.lg) {
            Spacer()
            LUMENOrbView(state: .idle, speechService: speechService, size: 120)

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

            if let url = speechService.recordingURL {
                LUMENButton(title: isUploading ? "Uploading..." : "Upload & Process",
                            icon: isUploading ? nil : "arrow.up.circle.fill", style: .primary) {
                    uploadMeeting(url: url)
                }
                .disabled(isUploading)
                .padding(.horizontal, LM.Space.md)
            }

            Button("Discard Recording") { speechService.recordingURL = nil }
                .font(LM.Fonts.text(13))
                .foregroundColor(LM.Colors.red.opacity(0.7))
                .padding(.bottom, LM.Space.xl)
        }
    }

    // MARK: - Actions
    func startRecording() {
        // Build 103: fresh meeting = fresh diagnostic log so previous meeting
        // noise doesn't contaminate this run's post-mortem.
        RecordingDiagnostics.shared.clear()
        RecordingDiagnostics.shared.log(.info, "====== startRecording() called — fresh meeting ======")
        // Stop any active attendee voice inputs — they hold AVAudioSession
        // and will crash SpeechRecognizerService.startListening() if still active.
        voiceInput.stop()
        emailVoiceInput.stop()
        // Small delay to let AVAudioSession release before we claim it again.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self._startRecordingImpl()
        }
    }

    func _startRecordingImpl() {
        lumen.reset()                       // clears word count, buffers, sets orbState=.idle
        lumen.orbState = .listening         // override immediately AFTER reset
        speechService.startListening()
        elapsedSeconds = 0
        // Build 100: capture the recording's real start time so the recovery header
        // can report accurate duration if we crash mid-meeting.
        recordingStartedAt = Date()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            // Build 100: Only tick the counter when audio is ACTUALLY being captured.
            // A silently-dead engine (post phone-call resume failure) now freezes the
            // counter instead of lying to the user. The health check also runs every
            // tick to detect and either recover or halt on dead engines.
            if speechService.isCapturingAudio {
                elapsedSeconds += 1
            }
            lumen.checkTriggerTimeout()
            verifyRecordingHealth()
        }

        // Build 90: Keep iPhone screen awake for the entire meeting. Cleared in stopRecording().
        UIApplication.shared.isIdleTimerDisabled = true

        // Build 90/100: Auto-flush the live transcript to disk every 30 seconds so
        // a crash, watchdog kill, or memory eviction can never wipe a long meeting.
        // Build 100 adds a header block (STARTED_AT / LAST_FLUSH) so the launch-time
        // recovery prompt can report meaningful duration to the user. On clean stop
        // the file is deleted; if it survives to next launch, DonsNotesApp offers
        // to finalize it as a completed meeting.
        flushTimer?.invalidate()
        let startTime = recordingStartedAt ?? Date()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            let text = speechService.transcript
            TranscriptRecoveryService.flush(transcript: text, startedAt: startTime)
        }

        // Build 91: AVAudioSession interruption observer — handles Siri, alarms, AirPods.
        // Cellular calls do NOT include .shouldResume so they are handled by CTCallCenter below.
        if interruptionObserver == nil {
            interruptionObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: nil,
                queue: .main
            ) { notification in
                guard let info = notification.userInfo,
                      let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
                switch type {
                case .began:
                    RecordingDiagnostics.shared.log(.interrupt, "AVAudioSession .began; wasListening=\(speechService.isListening)")
                    resumeAfterInterruption = speechService.isListening
                case .ended:
                    RecordingDiagnostics.shared.log(.interrupt, "AVAudioSession .ended; resumeAfterInterruption=\(resumeAfterInterruption)")
                    let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    // Only auto-resume for non-call interruptions that include .shouldResume.
                    // Call end is handled by CTCallCenter handler below.
                    if options.contains(.shouldResume), resumeAfterInterruption {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            if !speechService.isListening {
                                // Build 100: resume=true preserves the transcript captured
                                // before the interruption (Siri / alarm / AirPods).
                                speechService.startListening(resume: true)
                            }
                        }
                    }
                    resumeAfterInterruption = false
                @unknown default: break
                }
            }
        }

        // Build 91: CTCallCenter — watches cellular call state.
        // Fires on a background thread; always dispatch to @MainActor.
        // When a call starts: show banner, mark resume-needed.
        // When call ends: hide banner, force-restart recording (no .shouldResume needed).
        let cc = CTCallCenter()
        callCenter = cc
        cc.callEventHandler = { call in
            Task { @MainActor in
                switch call.callState {
                case CTCallStateConnected, CTCallStateDialing, CTCallStateIncoming:
                    RecordingDiagnostics.shared.log(.call, "CTCallState=Connected/Dialing/Incoming; isListening=\(speechService.isListening)")
                    if speechService.isListening {
                        resumeAfterInterruption = true
                    }
                    phoneCallBannerVisible = true
                case CTCallStateDisconnected:
                    RecordingDiagnostics.shared.log(.call, "CTCallState=Disconnected; resumeAfterInterruption=\(resumeAfterInterruption)")
                    phoneCallBannerVisible = false
                    if resumeAfterInterruption {
                        resumeAfterInterruption = false
                        // Build 101: Extended retry ladder — declined cellular calls
                        // can take iOS 4-8 seconds to release the audio session (much
                        // longer than answered-then-hung-up calls). Build 100's
                        // 0.8/1.5/2.5s ladder gave up before iOS was ready. Now:
                        // 1s, 2s, 4s, 7s, 12s — total wait ~26s covers even worst-case
                        // WiFi-calling / Do Not Disturb teardowns. If all 5 fail, the
                        // alarm banner fires AND launches a background auto-retry that
                        // keeps trying every 3s so the user can just wait and watch
                        // recording resume on its own.
                        let delays: [UInt64] = [
                            1_000_000_000,
                            2_000_000_000,
                            4_000_000_000,
                            7_000_000_000,
                            12_000_000_000,
                        ]
                        var resumed = false
                        for (i, delay) in delays.enumerated() {
                            resumeRetryCount = i + 1
                            RecordingDiagnostics.shared.log(.retry, "post-call retry attempt \(i+1)/5 delay=\(delay/1_000_000_000)s")
                            try? await Task.sleep(nanoseconds: delay)
                            // Build 101: attempts 1-2 use gentle startListening. Attempts
                            // 3-5 escalate to forceRestart because by then the mic is
                            // clearly zombied and needs an explicit audio-session teardown.
                            if i < 2 {
                                if !speechService.isListening {
                                    speechService.startListening(resume: true)
                                }
                            } else {
                                RecordingDiagnostics.shared.log(.retry, "attempt \(i+1) escalates to forceRestart")
                                speechService.forceRestart(resume: true)
                                // Extra 600ms for forceRestart's own 500ms teardown delay.
                                try? await Task.sleep(nanoseconds: 600_000_000)
                            }
                            // Wait briefly for the tap to start delivering buffers.
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            RecordingDiagnostics.shared.log(.retry, "attempt \(i+1) result: isCapturingAudio=\(speechService.isCapturingAudio) isListening=\(speechService.isListening)")
                            if speechService.isCapturingAudio {
                                resumed = true
                                break
                            }
                        }
                        resumeRetryCount = 0
                        if !resumed {
                            // Audio engine still dead after ~26s of escalating retries.
                            // Fire the alarm AND start the silent background auto-retry
                            // loop so the user gets automatic recovery if iOS releases
                            // the session late.
                            RecordingDiagnostics.shared.log(.ui, "ALARM raised (post-call retries exhausted); starting auto-resume loop")
                            recordingHaltReason = "Recording didn't restart after your phone call yet. Trying to resume automatically…"
                            recordingHealthAlarm = true
                            lumen.orbState = .idle
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.error)
                            startAutoResumeLoop()
                        }
                    }
                default:
                    break
                }
            }
        }
    }

    // Build 100: Every-second health check called by the recording timer.
    // Detects a silently-dead audio engine that no interruption handler caught
    // (e.g. background app kill, mic hardware fault, USB audio disconnect).
    // Requires 5 seconds of consecutive dead-engine readings before halting to
    // avoid false positives from transient buffer gaps.
    func verifyRecordingHealth() {
        guard speechService.isListening,
              !recordingHealthAlarm,
              !phoneCallBannerVisible,
              resumeRetryCount == 0 else {
            // Reset counter if we're intentionally paused or already halted.
            deadEngineTicks = 0
            return
        }
        if speechService.isCapturingAudio {
            deadEngineTicks = 0
        } else {
            deadEngineTicks += 1
            if deadEngineTicks >= 5 {
                // 5 seconds of no audio buffers while supposedly listening = dead.
                RecordingDiagnostics.shared.log(.ui, "ALARM raised (health-check: 5s no buffers); starting auto-resume")
                recordingHaltReason = "Recording stopped unexpectedly. Trying to resume automatically…"
                recordingHealthAlarm = true
                lumen.orbState = .idle
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                deadEngineTicks = 0
                // Build 101: also kick off the background auto-retry loop from
                // this dead-engine path (not just phone-call disconnect).
                startAutoResumeLoop()
            }
        }
    }

    /// Build 101: Silent background retry loop that runs while the alarm banner
    /// is showing. Tries startListening(resume: true) every 3 seconds. On the
    /// first attempt where real audio buffers flow, dismisses the banner, gives
    /// a soft success haptic, and lets the meeting continue.
    ///
    /// Cancellation: manual RETRY / SAVE / stopRecording call cancelAutoResumeLoop().
    /// Also self-cancels after 20 attempts (~60 seconds) to avoid running forever.
    func startAutoResumeLoop() {
        cancelAutoResumeLoop()  // never allow two loops in flight
        RecordingDiagnostics.shared.log(.retry, "autoResumeLoop started")
        autoResumeTask = Task { @MainActor in
            for tick in 0..<20 {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { RecordingDiagnostics.shared.log(.retry, "autoResumeLoop cancelled at tick \(tick)"); return }
                // If the user already handled it (Save / manual Retry), bail.
                if !recordingHealthAlarm { RecordingDiagnostics.shared.log(.retry, "autoResumeLoop exit (alarm cleared) tick \(tick)"); return }
                RecordingDiagnostics.shared.log(.retry, "autoResumeLoop tick \(tick+1)/20 → forceRestart")
                // Build 101: use forceRestart in the background loop — by definition
                // we're in zombie state (alarm is up because engine died), so a plain
                // startListening will hit the isListening guard and no-op forever.
                speechService.forceRestart(resume: true)
                // forceRestart has its own internal 500ms teardown delay, plus tap
                // startup latency. Give it 1.2s total before checking.
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if Task.isCancelled { return }
                RecordingDiagnostics.shared.log(.retry, "tick \(tick+1) post-check: isCapturingAudio=\(speechService.isCapturingAudio) isListening=\(speechService.isListening)")
                if speechService.isCapturingAudio {
                    // Recovered on its own — dismiss alarm, resume normal state.
                    recordingHealthAlarm = false
                    lumen.orbState = .listening
                    deadEngineTicks = 0
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    return
                }
            }
            // Ran out of attempts — update the banner to stop promising recovery.
            if recordingHealthAlarm {
                recordingHaltReason = "Recording didn't restart after your phone call. Tap Save to keep what was captured before the call."
            }
        }
    }

    func cancelAutoResumeLoop() {
        autoResumeTask?.cancel()
        autoResumeTask = nil
    }

    func stopRecording() {
        cancelAutoResumeLoop()
        speechService.stopListening()
        recordingTimer?.invalidate()
        recordingTimer = nil
        lumen.orbState = .idle

        // Build 90: tear down keep-awake + auto-flush + interruption observer
        UIApplication.shared.isIdleTimerDisabled = false
        flushTimer?.invalidate()
        flushTimer = nil
        if let obs = interruptionObserver {
            NotificationCenter.default.removeObserver(obs)
            interruptionObserver = nil
        }
        // Build 91: tear down CTCallCenter monitor and dismiss banner.
        callCenter?.callEventHandler = nil
        callCenter = nil
        phoneCallBannerVisible = false
        // Build 100: Clear the recovery file since the meeting ended cleanly.
        // (uploadMeeting path also clears it — this covers the discard path.)
        TranscriptRecoveryService.clear()
    }

    func toggleVoiceDictation() {
        if voiceInput.isRecording {
            voiceInput.stop()
        } else {
            voiceInput.start(seconds: 3)
        }
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
        updatePreMeetingBrief() // Build 96
    }

    func presentRecapSheet(text: String, recipients: [String] = [], subject: String = "") {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else {
            dismiss(); return
        }

        // Find the top-most presenter
        var presenter = root
        while let p = presenter.presentedViewController, !p.isBeingDismissed { presenter = p }
        let dismissAction = dismiss

        // Extract body (strip first line which is the subject duplicate)
        let bodyOnly = text
            .split(separator: "\n\n", maxSplits: 1, omittingEmptySubsequences: false)
            .dropFirst()
            .joined(separator: "\n\n")

        // If we have recipients AND the device can send mail, present the
        // native Mail composer directly. This is the only reliable way to
        // pre-fill To:/Subject:/Body: — share sheets stringify mailto: URLs.
        if !recipients.isEmpty, MFMailComposeViewController.canSendMail() {
            let mc = MFMailComposeViewController()
            let delegate = RecapMailDelegate { _ in
                DispatchQueue.main.async { dismissAction() }
            }
            mc.mailComposeDelegate = delegate
            // Retain delegate on the controller — it's a class so this is safe
            objc_setAssociatedObject(mc, &RecapMailDelegate.assocKey, delegate, .OBJC_ASSOCIATION_RETAIN)
            mc.setToRecipients(recipients)
            mc.setSubject(subject)
            mc.setMessageBody(bodyOnly, isHTML: false)
            presenter.present(mc, animated: true)
            return
        }

        // Fallback: no recipients (or device can't send mail) — show share
        // sheet with plain text so Messages/Copy/Notes still work.
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = window
            pop.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        vc.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async { dismissAction() }
        }
        presenter.present(vc, animated: true)
    }

    func toggleAttendee(_ contact: Attendee) {
        if let i = attendees.firstIndex(where: { $0.email == contact.email }) { attendees.remove(at: i) }
        else { attendees.append(contact) }
        updatePreMeetingBrief()
    }

    // Build 96: Pre-meeting brief — find the most recent past meeting that includes any current attendee
    func updatePreMeetingBrief() {
        guard !attendees.isEmpty else { withAnimation { preMeetingBrief = nil }; return }
        let emails = Set(attendees.map { $0.email.lowercased() })
        let all = MeetingCacheService.shared.loadMeetings()
        let match = all
            .filter { ($0.status == .completed || $0.status == .sent) }
            .filter { m in m.attendees.contains(where: { emails.contains($0.email.lowercased()) }) }
            .sorted { $0.createdAt > $1.createdAt }
            .first
        withAnimation { preMeetingBrief = match }
    }

    // Build 96: Pre-meeting brief card UI
    @ViewBuilder
    func preMeetingBriefCard(_ meeting: Meeting) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — tap to expand/collapse
            Button(action: { withAnimation(.spring(response: 0.3)) { briefExpanded.toggle() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12))
                        .foregroundColor(LM.Colors.cyan)
                    Text("LAST MEETING — \(meeting.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(LM.Fonts.mono(10, weight: .bold))
                        .foregroundColor(LM.Colors.cyan)
                        .tracking(1)
                    Spacer()
                    Image(systemName: briefExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11))
                        .foregroundColor(LM.Colors.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if briefExpanded {
                Divider().background(LM.Colors.borderCyan.opacity(0.4))

                VStack(alignment: .leading, spacing: 8) {
                    // Attendees who overlap
                    let names = meeting.attendees.map { $0.name }.joined(separator: ", ")
                    if !names.isEmpty {
                        Label(names, systemImage: "person.2")
                            .font(LM.Fonts.text(12))
                            .foregroundColor(LM.Colors.textSecondary)
                    }

                    // Summary snippet
                    if let summary = meeting.summary {
                        Text(summary.prefix(320) + (summary.count > 320 ? "..." : ""))
                            .font(LM.Fonts.text(12))
                            .foregroundColor(LM.Colors.textTertiary)
                            .lineSpacing(4)
                    }

                    // Action items still open
                    if let items = meeting.actionItems, !items.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Open Action Items")
                                .font(LM.Fonts.mono(9, weight: .bold))
                                .foregroundColor(LM.Colors.cyan)
                                .tracking(1)
                            ForEach(items.prefix(3), id: \.self) { item in
                                HStack(alignment: .top, spacing: 6) {
                                    Circle().fill(LM.Colors.cyan).frame(width: 4, height: 4).padding(.top, 5)
                                    Text(item)
                                        .font(LM.Fonts.text(12))
                                        .foregroundColor(LM.Colors.textSecondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(LM.Colors.surface)
        .cornerRadius(LM.Radius.sm)
        .overlay(RoundedRectangle(cornerRadius: LM.Radius.sm)
            .stroke(LM.Colors.borderCyan.opacity(0.6), lineWidth: 1))
    }

    func uploadMeeting(url: URL) {
        isUploading = true
        Task {
            // Use lumen.meetingTranscript (human-only text, Ora exchanges stripped in real time)
            // Append any remaining text after the last Ora exchange too
            let rawFull = await MainActor.run { speechService.transcript.trimmingCharacters(in: .whitespacesAndNewlines) }
            let meetingOnly = await MainActor.run { lumen.meetingTranscript.trimmingCharacters(in: .whitespacesAndNewlines) }
            // Append any tail text after last Ora exchange
            let lastEnd = await MainActor.run { lumen.lastOraExchangeEndIndex }
            let tailText: String
            if lastEnd < rawFull.count {
                let idx = rawFull.index(rawFull.startIndex, offsetBy: min(lastEnd, rawFull.count))
                tailText = String(rawFull[idx...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else { tailText = "" }
            let transcript = meetingOnly.isEmpty ? rawFull :
                (tailText.isEmpty ? meetingOnly : meetingOnly + " " + tailText)
            let insights = await MainActor.run { lumen.insights }
            let attendeesCopy = await MainActor.run { attendees }
            let organizer = await MainActor.run { profileService.userName }

            // transcript is already clean (meetingTranscript strips Ora exchanges in real time)
            let cleanTranscript = transcript

            // Ask Groq for a structured summary + action items if we have transcript
            var summary: String? = nil
            var actionItems: [String]? = nil

            if !cleanTranscript.isEmpty {
                if let result = try? await summarizeWithGroq(transcript: cleanTranscript) {
                    summary = result.summary
                    actionItems = result.actionItems.isEmpty ? nil : result.actionItems
                }
            }

            // Build 98: Speaker diarization — attribute transcript turns to attendee names
            // Runs in parallel after summary; falls back gracefully if it fails.
            var speakerTranscript: String? = nil
            if !cleanTranscript.isEmpty {
                let speakerNames = attendeesCopy.map { $0.name }.filter { !$0.isEmpty }
                speakerTranscript = try? await GroqClient.diarizeTranscript(
                    cleanTranscript,
                    speakerNames: speakerNames,
                    organizerName: organizer.isEmpty ? nil : organizer
                )
            }

            // Fall back to Ora Q&A insights if Groq summary failed
            if summary == nil && !insights.isEmpty {
                summary = insights.map { "Q: \($0.question)\nA: \($0.answer)" }.joined(separator: "\n\n")
            }

            let meeting = Meeting(
                id: UUID(),
                status: .completed,
                audioUrl: url.absoluteString,
                transcript: cleanTranscript.isEmpty ? nil : cleanTranscript,
                summary: summary,
                attendees: attendeesCopy,
                organizerName: organizer.isEmpty ? nil : organizer,
                createdAt: Date(),
                actionItems: actionItems,
                insights: insights.isEmpty ? nil : insights,
                speakerTranscript: speakerTranscript
            )
            await MainActor.run {
                var saved = MeetingCacheService.shared.loadMeetings()
                saved.insert(meeting, at: 0)
                MeetingCacheService.shared.saveMeetings(saved)
                isUploading = false

                // Present share sheet BEFORE dismissing — once dismiss() fires the view
                // is gone and no sheet can present from it.
                if !cleanTranscript.isEmpty || summary != nil || !attendeesCopy.isEmpty {
                    let subject = "Meeting Recap - \(meeting.createdAt.formatted(date: .abbreviated, time: .omitted))"
                    var body = "Meeting Recap — ORA\n"
                    body += "Date: \(meeting.createdAt.formatted(date: .long, time: .shortened))\n"
                    if let org = meeting.organizerName, !org.isEmpty { body += "Organizer: \(org)\n" }
                    if !attendeesCopy.isEmpty {
                        body += "Attendees: \(attendeesCopy.map { "\($0.name) <\($0.email)>" }.joined(separator: ", "))\n"
                    }
                    body += "\n"
                    if let s = summary { body += "SUMMARY\n\(s)\n\n" }
                    if let items = actionItems, !items.isEmpty {
                        body += "ACTION ITEMS\n"
                        for (i, item) in items.enumerated() { body += "  \(i+1). \(item)\n" }
                        body += "\n"
                    }
                    if let ins = meeting.insights, !ins.isEmpty {
                        body += "ORA INSIGHTS\n"
                        for i in ins { body += "Q: \(i.question)\nA: \(i.answer)\n\n" }
                    }
                    // Build 98: prefer speaker-attributed transcript in email; fall back to raw
                    if let spk = speakerTranscript, !spk.isEmpty {
                        body += "FULL TRANSCRIPT (Speaker Attributed)\n\(spk)\n"
                    } else if !cleanTranscript.isEmpty {
                        body += "FULL TRANSCRIPT\n\(cleanTranscript)\n"
                    }
                    body += "\n— Sent via ORA · AI Meeting Intelligence"
                    let recipientEmails = attendeesCopy
                        .map { $0.email.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    presentRecapSheet(text: "\(subject)\n\n\(body)", recipients: recipientEmails, subject: subject)
                } else {
                    dismiss()
                }
            }
        }
    }

    struct SummaryResult {
        let summary: String
        let actionItems: [String]
    }

    func summarizeWithGroq(transcript: String) async throws -> SummaryResult {
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Config.groqKey)", forHTTPHeaderField: "Authorization")

        let prompt = """
        You are summarizing a business meeting transcript. The transcript may contain speech recognition artifacts. Ignore any fragments that look like AI assistant commands or responses. Focus only on the human meeting conversation.

        Produce a STRUCTURED meeting summary with these EXACT section headers, in this order, each on its own line. Skip a section only if there is genuinely nothing to put there (do not write "none" or "N/A").

        OVERVIEW
        A 2-4 sentence paragraph describing what the meeting was about.

        KEY DECISIONS
        - One bullet per decision actually made. If none were made, omit this section entirely.

        ACTION ITEMS
        - PERSON: action by WHEN (or PERSON: action if no when was stated)
        - One bullet per item. Be specific about who owns it.

        OPEN QUESTIONS
        - Unresolved questions or things that need follow-up. Omit section if none.

        NEXT STEPS
        - Concrete next-meeting or next-week items. Omit section if none.

        Use the EXACT header words above in ALL CAPS, each header on its own line with no colon, no markdown, no emojis. Bullets start with "- ".

        Transcript:
        \(transcript.prefix(100000))
        """

        let body: [String: Any] = [
            "model": Config.groqModel,
            "max_tokens": 1500,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = (json?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any]
        let text = (content?["content"] as? String) ?? ""

        // Build 90: parse Plaud-style structured response with named sections.
        // The full structured text becomes `summary`. Action items are also
        // extracted as a separate list for the ACTION ITEMS UI section.
        let knownHeaders: Set<String> = ["OVERVIEW", "KEY DECISIONS", "ACTION ITEMS", "OPEN QUESTIONS", "NEXT STEPS"]
        var items: [String] = []
        let lines = text.components(separatedBy: "\n")
        var currentSection: String = ""
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let upper = trimmed.uppercased()
            if knownHeaders.contains(upper) {
                currentSection = upper
                continue
            }
            if currentSection == "ACTION ITEMS", trimmed.hasPrefix("- ") {
                items.append(String(trimmed.dropFirst(2)))
            }
        }
        let cleanedSummary = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return SummaryResult(summary: cleanedSummary.isEmpty ? text : cleanedSummary, actionItems: items)
    }
}

// MARK: - Attendee Voice Input (one-shot dictation for the name field)
// A self-contained short speech-to-text helper, completely separate from the recording
// pipeline (SpeechRecognizerService). Only used while NOT recording, so the two never
// contend for the audio input.
final class AttendeeVoiceInput: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var dictatedText = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()
    private var autoStopWork: DispatchWorkItem?

    func start(seconds: TimeInterval) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self, status == .authorized else { return }
                self.beginCapture(seconds: seconds)
            }
        }
    }

    private func beginCapture(seconds: TimeInterval) {
        guard let recognizer = recognizer, recognizer.isAvailable else { return }

        // Tear down anything left over.
        stop()
        dictatedText = ""

        // Use .playAndRecord (same as SpeechRecognizerService) so the session
        // doesn't conflict if the user taps the mic button quickly after stopping.
        // .duckOthers keeps audio from other sources quiet while dictating.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        request = req

        task = recognizer.recognitionTask(with: req) { [weak self] result, _ in
            guard let self = self else { return }
            if let result = result {
                DispatchQueue.main.async {
                    self.dictatedText = result.bestTranscription.formattedString
                }
            }
        }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
            isRecording = true
        } catch {
            stop()
            return
        }

        // Auto-stop after the requested window.
        let work = DispatchWorkItem { [weak self] in self?.stop() }
        autoStopWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func stop() {
        autoStopWork?.cancel()
        autoStopWork = nil
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        isRecording = false
        // Release the session so the recording pipeline can claim it later.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - Mail compose delegate for recap email
// Used by RecordingView.presentRecapSheet to host MFMailComposeViewController.
// Held alive via objc_setAssociatedObject on the controller — released when
// the controller is dismissed.
final class RecapMailDelegate: NSObject, MFMailComposeViewControllerDelegate {
    static var assocKey: UInt8 = 0
    let onFinish: (MFMailComposeResult) -> Void
    init(onFinish: @escaping (MFMailComposeResult) -> Void) { self.onFinish = onFinish }
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true) { [onFinish] in onFinish(result) }
    }
}

// MARK: - Diagnostic log viewer (Build 103)
// Full-screen sheet showing the current in-memory diagnostic log. Reached by
// long-pressing the recording orb for 3 seconds. Provides a "Copy All" button
// (clipboard) and a "Share" button (native share sheet → AirDrop, Mail,
// Messages, iCloud Drive, etc). This is our forensic tool for post-mortem
// diagnosis of recording failures.
struct DiagnosticLogSheet: View {
    @Binding var isPresented: Bool
    @ObservedObject private var diag = RecordingDiagnostics.shared
    @State private var showShareSheet: Bool = false
    @State private var copyFeedback: Bool = false

    // Precomputed date formatter for row timestamps.
    private let ts: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    // Color per category so the eye can scan the log fast.
    private func color(for cat: DiagnosticCategory) -> Color {
        switch cat {
        case .call:       return .orange
        case .interrupt:  return .yellow
        case .engine:     return .cyan
        case .session:    return .mint
        case .recognizer: return .purple
        case .ui:         return .pink
        case .retry:      return .blue
        case .force:      return .red
        case .error:      return .red
        case .info:       return .gray
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header stats
                HStack {
                    Text("\(diag.entries.count) entries")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?")")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Divider().padding(.top, 4)

                // The scrolling log itself.
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(diag.entries) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(ts.string(from: entry.timestamp))
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .leading)
                                    Text(entry.category.rawValue)
                                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                                        .foregroundColor(color(for: entry.category))
                                        .frame(width: 60, alignment: .leading)
                                    Text(entry.message)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.horizontal)
                                .id(entry.id)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onAppear {
                        // Jump to the newest entry.
                        if let last = diag.entries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: diag.entries.count) { _, _ in
                        if let last = diag.entries.last {
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // Action bar
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = diag.exportText()
                        copyFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            copyFeedback = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copyFeedback ? "checkmark" : "doc.on.clipboard")
                            Text(copyFeedback ? "Copied" : "Copy All")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .navigationTitle("Recording Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                DiagnosticShareSheet(items: [diag.exportText()])
            }
        }
    }
}

// UIKit share sheet wrapper — used to hand the diagnostic log to AirDrop /
// Mail / Messages / iCloud Drive.
struct DiagnosticShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
