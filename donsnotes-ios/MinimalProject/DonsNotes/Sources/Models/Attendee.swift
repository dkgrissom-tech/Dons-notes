import Foundation

struct Attendee: Codable, Identifiable {
    var id: String { email }
    let email: String
    let name: String
}
