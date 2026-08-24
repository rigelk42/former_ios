import SwiftUI
import UIKit

/// Thin wrapper around UIActivityViewController -- SwiftUI's ShareLink
/// wants its item ready synchronously, but the invoice PDF has to be
/// fetched from the network first, so this is presented via .sheet once
/// the fetch completes instead.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
