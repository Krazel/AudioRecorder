import AVFoundation
import Foundation

@MainActor
final class AudioPlaybackService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var playingID: UUID?
    @Published var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var lastError: String?

    private var player: AVAudioPlayer?
    private var timer: Timer?

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
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: item.fileURL)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            self.player = player
            playingID = item.id
            currentTime = 0
            duration = player.duration
            startTimer()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        playingID = nil
        currentTime = 0
        duration = 0
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let boundedTime = min(max(time, 0), player.duration)
        player.currentTime = boundedTime
        currentTime = boundedTime
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
                self.duration = player.duration
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}
