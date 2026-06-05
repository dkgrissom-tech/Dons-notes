import SwiftUI

struct ContactPickerView<T: APIServiceProtocol>: View {
    @ObservedObject var apiService: T
    @Binding var selectedAttendees: [Attendee]
    @State private var contacts: [Attendee] = []
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                } else {
                    List(contacts) { contact in
                        Button(action: {
                            toggleSelection(contact)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(contact.name)
                                        .font(.headline)
                                    Text(contact.email)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                if selectedAttendees.contains(where: { $0.email == contact.email }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if !isLoading && contacts.isEmpty {
                    VStack {
                        Text("No saved contacts")
                            .foregroundColor(.gray)
                        Text("Contacts are saved automatically when you add them to a meeting.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
            }
            .onAppear(perform: loadContacts)
        }
    }
    
    private func loadContacts() {
        isLoading = true
        Task {
            do {
                let fetchedContacts = try await apiService.fetchContacts()
                await MainActor.run {
                    self.contacts = fetchedContacts
                    isLoading = false
                }
            } catch {
                print("Failed to fetch contacts: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func toggleSelection(_ contact: Attendee) {
        if let index = selectedAttendees.firstIndex(where: { $0.email == contact.email }) {
            selectedAttendees.remove(at: index)
        } else {
            selectedAttendees.append(contact)
        }
    }
}
