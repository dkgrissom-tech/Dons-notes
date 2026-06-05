import Foundation

class MeetingCacheService {
    static let shared = MeetingCacheService()
    
    private let cacheKey = "cached_meetings"
    
    func saveMeetings(_ meetings: [Meeting]) {
        do {
            let data = try JSONEncoder().encode(meetings)
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            print("Failed to cache meetings: \(error)")
        }
    }
    
    func loadMeetings() -> [Meeting] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return [] }
        do {
            return try JSONDecoder().decode([Meeting.self], from: data)
        } catch {
            print("Failed to load cached meetings: \(error)")
            return []
        }
    }
}
