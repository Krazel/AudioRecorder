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

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
