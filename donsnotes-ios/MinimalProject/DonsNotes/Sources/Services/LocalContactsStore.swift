import Foundation

/// Local-only contact persistence. UserDefaults-backed so it survives force-quit and relaunch.
/// Part of Build 86 — no backend.
final class LocalContactsStore {
    static let shared = LocalContactsStore()
    private let key = "ora_local_contacts"

    private init() {}

    func load() -> [Attendee] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Attendee].self, from: data)) ?? []
    }

    func save(_ attendee: Attendee) {
        var current = load()
        if let idx = current.firstIndex(where: { $0.email.lowercased() == attendee.email.lowercased() }) {
            current[idx] = attendee
        } else {
            current.append(attendee)
        }
        if let data = try? JSONEncoder().encode(current) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
