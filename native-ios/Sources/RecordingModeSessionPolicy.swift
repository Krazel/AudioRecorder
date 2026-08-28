import Foundation

enum RecordingModeSessionPolicy {
    static func modeForNextSegment(
        configuredMode: RecordingMode,
        activeMode: RecordingMode?,
        isRecording: Bool
    ) -> RecordingMode {
        guard isRecording, let activeMode else {
            return configuredMode
        }

        return activeMode
    }
}
