import AVFoundation
import Foundation

@MainActor
final class AudioPlaybackService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingID: UUID?
    @Published private(set) var lastError: String?

    private var player: AVAudioPlayer?

    func toggle(_ item: RecordingItem) {
        if playingID == item.id {
            stop()
        } else {
            play(item)
        }
    }

    func play(_ item: RecordingItem) {
        do {
            stop()
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: item.fileURL)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            self.player = player
            playingID = item.id
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}
