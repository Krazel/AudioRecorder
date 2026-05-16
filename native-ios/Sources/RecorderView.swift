import SwiftUI

struct RecorderView: View {
    @EnvironmentObject private var recorder: RecorderService
    @EnvironmentObject private var settings: RecordingSettingsStore
    @EnvironmentObject private var library: RecordingLibrary
    @EnvironmentObject private var uploadQueue: CloudUploadQueue

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text(recorder.isRecording ? "Grabando" : "Preparado")
                        .font(.largeTitle.weight(.semibold))
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ZStack {
                    Circle()
                        .fill(recorder.isRecording ? .red.opacity(0.16) : .gray.opacity(0.12))
                        .frame(width: 220, height: 220)
                    Circle()
                        .stroke(recorder.isRecording ? .red : .secondary, lineWidth: 4)
                        .frame(width: 174, height: 174)
                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundStyle(recorder.isRecording ? .red : .primary)
                }
                .contentShape(Circle())
                .onTapGesture {
                    toggleRecording()
                }

                HStack(spacing: 16) {
                    MetricView(title: "Segmento", value: formatTime(recorder.elapsed))
                    MetricView(title: "Nivel", value: "\(Int(recorder.currentLevel)) dB")
                }

                VStack(spacing: 12) {
                    DetailRow(title: "Modo", value: settings.mode.title)
                    DetailRow(title: "Calidad", value: settings.quality.title)
                    DetailRow(title: "Corte", value: "\(settings.segmentMinutes) min")
                    DetailRow(title: "Subida", value: settings.uploadAutomatically ? settings.cloudProvider.title : "No")
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if let error = recorder.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Audio")
        }
    }

    private var statusText: String {
        if recorder.isRecording {
            "Se crea un archivo nuevo cada \(settings.segmentMinutes) minutos"
        } else {
            "Toca el micrófono para empezar"
        }
    }

    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stop()
        } else {
            Task {
                await recorder.start(settings: settings, library: library, uploadQueue: uploadQueue)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct MetricView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2.monospacedDigit().weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
