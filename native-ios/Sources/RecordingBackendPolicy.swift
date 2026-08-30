enum RecordingBackend: Equatable {
    case continuousAudioEngine
}

enum RecordingBackendPolicy {
    static func backend(for mode: RecordingMode) -> RecordingBackend {
        switch mode {
        case .everything, .soundActivated:
            return .continuousAudioEngine
        }
    }

    static let stopsCaptureDuringSegmentRotation = false
}

enum RecordingRetryGate {
    static func wait(nanoseconds: UInt64) async -> Bool {
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}
