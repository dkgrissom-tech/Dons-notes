import SwiftUI
import AVFoundation

struct RecordingView<T: APIServiceProtocol>: View {
    @StateObject var recorder = AudioRecorder()
    @ObservedObject var apiService: T
    @ObservedObject var contactService = ContactService.shared
    @ObservedObject var profileService = ProfileService.shared
    @StateObject var speechService = SpeechRecognizerService()
    @State private var attendees: [Attendee] = []
    @State private var newAttendeeEmail = ""
    @State private var newAttendeeName = ""
    @State private var isUploading = false
    @State private var isShowingContactPicker = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                DNColors.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if !recorder.isRecording && recorder.recordingURL == nil {
                        setupSection
                    } else {
                        recordingSection
                    }
                }
                .padding()
            }
            .navigationTitle(recorder.isRecording ? "Recording" : "New Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DNColors.textSecondary)
                }
            }
            .onAppear {
                Task { await contactService.syncContacts(from: apiService) }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private var setupSection: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title
                VStack(spacing: 6) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 40))
                        .foregroundColor(DNColors.accent)
                    Text("New Meeting")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(DNColors.textPrimary)
                    if !profileService.userName.isEmpty {
                        Text("Organizer: \(profileService.userName)")
                            .font(.system(size: 14))
                            .foregroundColor(DNColors.textSecondary)
                    }
                }
                .padding(.top, 10)
                
                // Quick Add Contacts
                if !contactService.savedContacts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("QUICK ADD")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(DNColors.textTertiary)
                            .tracking(1.2)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(contactService.savedContacts) { contact in
                                    Button(action: { toggleAttendee(contact) }) {
                                        let isSelected = attendees.contains(where: { $0.email == contact.email })
                                        VStack(spacing: 6) {
                                            ZStack {
                                                Circle()
                                                    .fill(isSelected ? DNColors.accent : DNColors.surface)
                                                    .frame(width: 48, height: 48)
                                                Text(String(contact.name.prefix(1)).uppercased())
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(isSelected ? .white : DNColors.textSecondary)
                                            }
                                            Text(contact.name.components(separatedBy: " ").first ?? contact.name)
                                                .font(.system(size: 11))
                                                .foregroundColor(isSelected ? DNColors.accent : DNColors.textTertiary)
                                                .lineLimit(1)
                                        }
                                        .frame(width: 72)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Add New Attendee
                VStack(alignment: .leading, spacing: 10) {
                    Text("ADD ATTENDEE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(DNColors.textTertiary)
                        .tracking(1.2)
                        .padding(.horizontal)
                    
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            DNTextField(placeholder: "Name", text: $newAttendeeName)
                            DNTextField(placeholder: "Email", text: $newAttendeeEmail)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        .padding(.horizontal)
                        
                        HStack(spacing: 12) {
                            Button(action: addAttendee) {
                                Label("Add", systemImage: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                                    .background(newAttendeeEmail.isEmpty || newAttendeeName.isEmpty ? DNColors.surface : DNColors.accent)
                                    .foregroundColor(newAttendeeEmail.isEmpty || newAttendeeName.isEmpty ? DNColors.textTertiary : .white)
                                    .cornerRadius(10)
                            }
                            .disabled(newAttendeeEmail.isEmpty || newAttendeeName.isEmpty)
                            
                            Button(action: toggleListening) {
                                HStack(spacing: 6) {
                                    Image(systemName: speechService.isListening ? "mic.fill" : "mic")
                                        .font(.system(size: 14))
                                    Text(speechService.isListening ? "Listening..." : "Dictate")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(speechService.isListening ? Color.red.opacity(0.2) : DNColors.surface)
                                .foregroundColor(speechService.isListening ? .red : DNColors.textSecondary)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(speechService.isListening ? Color.red.opacity(0.4) : DNColors.divider, lineWidth: 1))
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    if speechService.isListening {
                        HStack(spacing: 3) {
                            ForEach(0..<20) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.red.opacity(0.7))
                                    .frame(width: 3, height: CGFloat.random(in: 4...20))
                            }
                        }
                        .padding(.horizontal)
                        .animation(.easeInOut(duration: 0.3).repeatForever(), value: speechService.isListening)
                    }
                }
                
                // Attendees List
                if !attendees.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ATTENDEES (\(attendees.count))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(DNColors.textTertiary)
                            .tracking(1.2)
                            .padding(.horizontal)
                        
                        VStack(spacing: 1) {
                            ForEach(attendees) { attendee in
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(DNColors.accent.opacity(0.15))
                                            .frame(width: 36, height: 36)
                                        Text(String(attendee.name.prefix(1)).uppercased())
                                            .font(.system(size: 13, weight: .bold))
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
                                    Spacer()
                                    Button(action: {
                                        attendees.removeAll(where: { $0.email == attendee.email })
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(DNColors.textTertiary)
                                            .font(.system(size: 18))
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(DNColors.surface)
                            }
                        }
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                
                Spacer(minLength: 20)
                
                // Start Recording Button
                Button(action: { recorder.startRecording() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18))
                        Text("Start Recording")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .background(attendees.isEmpty ? DNColors.surface : DNColors.accent)
                    .foregroundColor(attendees.isEmpty ? DNColors.textTertiary : .white)
                    .cornerRadius(16)
                    .shadow(color: attendees.isEmpty ? .clear : DNColors.accent.opacity(0.4), radius: 16, x: 0, y: 6)
                }
                .disabled(attendees.isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .onChange(of: speechService.transcript, perform: { newValue in parseTranscript(newValue) })
    }
    
    private var recordingSection: some View {
        VStack(spacing: 40) {
            Spacer()
            
            if recorder.isRecording {
                VStack(spacing: 24) {
                    // Pulsing mic
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 120, height: 120)
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 90, height: 90)
                        Circle()
                            .fill(Color.red)
                            .frame(width: 64, height: 64)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    }
                    
                    Text("Recording...")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(DNColors.textPrimary)
                    
                    // Animated waveform
                    HStack(spacing: 4) {
                        ForEach(0..<24) { i in
                            AnimatedWaveBar(delay: Double(i) * 0.05)
                        }
                    }
                    .frame(height: 60)
                    .padding(.horizontal, 20)
                }
                
                Button(action: { recorder.stopRecording() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 16))
                        Text("Stop Recording")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .shadow(color: Color.red.opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .padding(.horizontal, 40)
                
            } else if let url = recorder.recordingURL {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(DNColors.successGreen.opacity(0.15))
                            .frame(width: 90, height: 90)
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(DNColors.successGreen)
                    }
                    
                    Text("Recording Saved")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(DNColors.textPrimary)
                    
                    Text("\(attendees.count) attendee\(attendees.count == 1 ? "" : "s") will receive the recap.")
                        .font(.system(size: 15))
                        .foregroundColor(DNColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button(action: { uploadMeeting(url: url) }) {
                        Group {
                            if isUploading {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Text("Uploading...")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Label("Upload & Process", systemImage: "arrow.up.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(16)
                        .background(DNColors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .shadow(color: DNColors.accent.opacity(0.4), radius: 12, x: 0, y: 4)
                    }
                    .disabled(isUploading)
                    .padding(.horizontal, 30)
                    
                    Button("Discard Recording") {
                        recorder.recordingURL = nil
                    }
                    .foregroundColor(Color.red.opacity(0.7))
                    .font(.system(size: 14))
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helpers (same as before)
    func addAttendee() {
        guard !newAttendeeEmail.isEmpty, !newAttendeeName.isEmpty else { return }
        let attendee = Attendee(email: newAttendeeEmail, name: newAttendeeName)
        if !attendees.contains(where: { $0.email == attendee.email }) {
            attendees.append(attendee)
            contactService.saveContact(attendee, via: apiService)
        }
        newAttendeeEmail = ""
        newAttendeeName = ""
    }
    
    func toggleAttendee(_ contact: Attendee) {
        if let index = attendees.firstIndex(where: { $0.email == contact.email }) {
            attendees.remove(at: index)
        } else {
            attendees.append(contact)
        }
    }
    
    func toggleListening() {
        if speechService.isListening { speechService.stopListening() }
        else { speechService.startListening() }
    }
    
    func parseTranscript(_ text: String) {
        let components = text.components(separatedBy: .whitespacesAndNewlines)
        var nameParts: [String] = []
        for component in components {
            if component.contains("@") { newAttendeeEmail = component.lowercased() }
            else if !component.isEmpty { nameParts.append(component) }
        }
        if !nameParts.isEmpty { newAttendeeName = nameParts.joined(separator: " ") }
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

// MARK: - Animated Waveform Bar
struct AnimatedWaveBar: View {
    let delay: Double
    @State private var height: CGFloat = 8
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.red.opacity(0.8))
            .frame(width: 4, height: height)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: Double.random(in: 0.4...0.8)).repeatForever(autoreverses: true).delay(delay)) {
                    height = CGFloat.random(in: 12...52)
                }
            }
    }
}

// MARK: - DN Text Field
struct DNTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField("", text: $text)
            .placeholder(when: text.isEmpty) {
                Text(placeholder).foregroundColor(DNColors.textTertiary)
            }
            .foregroundColor(DNColors.textPrimary)
            .padding(10)
            .background(DNColors.surface)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DNColors.divider, lineWidth: 1))
            .font(.system(size: 14))
    }
}
