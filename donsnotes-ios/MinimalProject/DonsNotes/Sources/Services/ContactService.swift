import Foundation

class ContactService: ObservableObject {
    static let shared = ContactService()
    
    @Published var savedContacts: [Attendee] = []
    
    private init() {}
    
    func syncContacts(from apiService: any APIServiceProtocol) async {
        do {
            let contacts = try await apiService.fetchContacts()
            await MainActor.run {
                self.savedContacts = contacts
            }
        } catch {
            print("Failed to sync contacts: \(error)")
        }
    }
    
    func saveContact(_ attendee: Attendee, via apiService: any APIServiceProtocol) {
        // Optimistically add to local list if not present
        if !savedContacts.contains(where: { $0.email == attendee.email }) {
            savedContacts.append(attendee)
        }
        
        Task {
            do {
                try await apiService.saveContact(attendee: attendee)
            } catch {
                print("Failed to save contact to backend: \(error)")
            }
        }
    }
}
