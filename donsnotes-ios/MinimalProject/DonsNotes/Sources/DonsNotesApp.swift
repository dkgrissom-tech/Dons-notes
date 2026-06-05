import SwiftUI

@main
struct DonsNotesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Toggle this to switch between Mock and Real API
    @StateObject var apiService = MockAPIService()
    // @StateObject var apiService = RealAPIService()

    var body: some Scene {
        WindowGroup {
            MeetingListView(apiService: apiService)
                .onOpenURL { url in
                    if url.scheme == "donsnotes" && url.host == "record" {
                        NotificationCenter.default.post(name: .startRecording, object: nil)
                    }
                }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if shortcutItem.type == "NewRecordingAction" {
            NotificationCenter.default.post(name: .startRecording, object: nil)
            completionHandler(true)
        } else {
            completionHandler(false)
        }
    }
}

extension Notification.Name {
    static let startRecording = Notification.Name("startRecording")
}
