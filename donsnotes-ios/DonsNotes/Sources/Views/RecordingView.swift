import SwiftUI

struct RecordingView<T: APIServiceProtocol>: View {
    @StateObject var recorder = AudioRecorder()
    @ObservedObject var apiService: T
    @ObservedObject var contactService = ContactService.shared
    @ObservedObject var profileService = ProfileService.shared
    @State private var attendees: [Attendee] = []
    @State private var newAttendeeEmail = ""
    @State private var newAttendeeName = ""
    @State private var isUploading = false
    @State private var isShowingContactPicker = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Flow control: Setup vs Recording
                if !recorder.isRecording && recorder.recordingURL == nil {
                    // SETUP PHASE: Add Attendees first
                    setupSection
                } else {
                    // RECORDING / UPLOAD PHASE
                    recordingSection
                }
            }
            .padding()
            .navigationTitle(recorder.isRecording ? "Recording" : "New Meeting")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await contactService.syncContacts(from: apiService)
                }
            }
        }
    }
    
    private var setupSection: some View {
        VStack(spacing: 15) {
            Text("Attendee Sign-In")
                .font(.title2)
                .bold()
            
            if !profileService.userName.isEmpty {
                Text("Organizer: \(profileService.userName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if !contactService.savedContacts.isEmpty {
                VStack(alignment: .leading) {
                    Text("Quick Add from Contacts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(contactService.savedContacts) { contact in
                                Button(action: { toggleAttendee(contact) }) {
                                    VStack {
                                        Image(systemName: "person.circle.fill")
                                            .font(.system(size: 30))
                                        Text(contact.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .padding(8)
                                    .frame(width: 80)
                                    .background(attendees.contains(where: { $0.email == contact.email }) ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(attendees.contains(where: { $0.email == contact.email }) ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                }
                                .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            VStack(alignment: .leading) {
                Text("Add New Attendee")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                HStack {
                    TextField("Name", text: $newAttendeeName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("Email", text: $newAttendeeEmail)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    Button(action: addAttendee) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                    }
                }
                .padding(.horizontal)
                
                if !attendees.isEmpty {
                    List {
                        ForEach(attendees) { attendee in
                            HStack {
                                Text(attendee.name)
                                Spacer()
                                Text(attendee.email)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .onDelete(perform: removeAttendee)
                    }
                    .listStyle(PlainListStyle())
                } else {
                    VStack {
                        Spacer()
                        Text("Add attendees to start")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
            
            Button(action: {
                recorder.startRecording()
            }) {
                Text("Start Recording")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(attendees.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(attendees.isEmpty)
            .padding(.horizontal)
        }
    }
    
    private var recordingSection: some View {
        VStack(spacing: 30) {
            if recorder.isRecording {
                VStack {
                    Text("Recording...")
                        .font(.title)
                        .foregroundColor(.red)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<10) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red)
                                .frame(width: 4, height: CGFloat.random(in: 10...50))
                        }
                    }
                }
                
                Button(action: {
                    recorder.stopRecording()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.red)
                }
            } else if let url = recorder.recordingURL {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.green)
                    
                    Text("Recording Saved")
                        .font(.title2)
                    
                    Text("\(attendees.count) attendees will receive the recap.")
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        uploadMeeting(url: url)
                    }) {
                        if isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        } else {
                            Text("Upload & Process")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isUploading)
                    
                    Button("Discard Recording") {
                        recorder.recordingURL = nil
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    func addAttendee() {
        guard !newAttendeeEmail.isEmpty, !newAttendeeName.isEmpty else { return }
        let attendee = Attendee(email: newAttendeeEmail, name: newAttendeeName)
        if !attendees.contains(where: { $0.email == attendee.email }) {
            attendees.append(attendee)
            // Auto-save to contacts
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
    
    func removeAttendee(at offsets: IndexSet) {
        attendees.remove(atOffsets: offsets)
    }
    
    func uploadMeeting(url: URL) {
        isUploading = true
        
        Task {
            do {
                _ = try await apiService.uploadMeeting(audioURL: url, attendees: attendees, organizerName: profileService.userName)
                await MainActor.run {
                    isUploading = false
                    dismiss()
                }
            } catch {
                print("Upload failed: \(error)")
                await MainActor.run {
                    isUploading = false
                }
            }
        }
    }
}

