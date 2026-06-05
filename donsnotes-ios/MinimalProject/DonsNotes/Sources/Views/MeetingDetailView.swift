import SwiftUI

struct MeetingDetailView<T: APIServiceProtocol>: View {
    @State var meeting: Meeting
    @ObservedObject var apiService: T
    @State private var timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @State private var isSendingEmail = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(meeting.status.displayName)
                        .font(.headline)
                        .padding(8)
                        .background(meeting.status.color.opacity(0.2))
                        .foregroundColor(meeting.status.color)
                        .cornerRadius(8)
                    
                    Spacer()
                    
                    Text(meeting.createdAt, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                if let organizer = meeting.organizerName, !organizer.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Organizer")
                            .font(.title3)
                            .bold()
                        Text(organizer)
                            .font(.body)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Attendees")
                        .font(.title3)
                        .bold()
                    ForEach(meeting.attendees) { attendee in
                        Text("\(attendee.name) (\(attendee.email))")
                            .font(.body)
                    }
                }
                
                if let summary = meeting.summary {
                    VStack(alignment: .leading) {
                        Text("Summary")
                            .font(.title3)
                            .bold()
                        Text(summary)
                            .font(.body)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                }
                
                if let transcript = meeting.transcript {
                    VStack(alignment: .leading) {
                        Text("Transcript")
                            .font(.title3)
                            .bold()
                        Text(transcript)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                if meeting.status == .completed {
                    Button(action: sendEmail) {
                        if isSendingEmail {
                            ProgressView()
                        } else {
                            Text("Send Recap Email")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(isSendingEmail)
                }
            }
            .padding()
        }
        .navigationTitle("Meeting Details")
        .onReceive(timer) { _ in
            if meeting.status != .completed && meeting.status != .sent && meeting.status != .failed {
                refreshMeeting()
            }
        }
    }
    
    func refreshMeeting() {
        Task {
            do {
                let updatedMeeting = try await apiService.fetchMeetingDetails(id: meeting.id)
                await MainActor.run {
                    self.meeting = updatedMeeting
                }
            } catch {
                print("Failed to refresh meeting: \(error)")
            }
        }
    }
    
    func sendEmail() {
        isSendingEmail = true
        Task {
            do {
                try await apiService.sendRecapEmail(id: meeting.id)
                refreshMeeting()
                await MainActor.run {
                    isSendingEmail = false
                }
            } catch {
                print("Failed to send email: \(error)")
                await MainActor.run {
                    isSendingEmail = false
                }
            }
        }
    }
}
