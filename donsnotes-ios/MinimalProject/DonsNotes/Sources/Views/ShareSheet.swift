import SwiftUI
import UIKit

/// Crash-proof share sheet for iOS 18.
/// Wraps UIActivityViewController via UIViewControllerRepresentable so SwiftUI's
/// sheet presentation handles lifecycle correctly. Replaces the old
/// `connectedScenes.first?.windows.first?.rootViewController` pattern that
/// crashed on iOS 18 when dismissed from inside a Form.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
