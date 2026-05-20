import SwiftUI
import UIKit

struct ShareItem: Identifiable {
    let id = UUID()
    let urls: [URL]
    let recordingIDs: [UUID]

    init(url: URL) {
        urls = [url]
        recordingIDs = []
    }

    init(urls: [URL], recordingIDs: [UUID] = []) {
        self.urls = urls
        self.recordingIDs = recordingIDs
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
