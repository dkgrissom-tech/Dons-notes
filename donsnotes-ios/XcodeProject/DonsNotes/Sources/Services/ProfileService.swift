import Foundation

class ProfileService: ObservableObject {
    static let shared = ProfileService()
    
    @Published var userName: String = ""
    
    private let nameKey = "user_profile_name"
    
    private init() {
        self.userName = UserDefaults.standard.string(forKey: nameKey) ?? ""
    }
    
    func saveName(_ name: String) {
        self.userName = name
        UserDefaults.standard.set(name, forKey: nameKey)
    }
}
