import SwiftUI

struct RecorderView: View {
    @EnvironmentObject private var recorder: RecorderService
    @EnvironmentObject private var settings: RecordingSettingsStore
    @EnvironmentObject private var library: RecordingLibrary

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    recorderContent
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: proxy.size.height)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var recorderContent: some View {
        VStack(spacing: 28) {
            Spacer()
                .frame(height: 24)

            VStack(spacing: 8) {
                Text(recorder.isRecording ? L("Grabando") : L("Preparado"))
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
                MetricView(title: "Segmento", value: formatTime(recorder.elapsed), scalesValueToFit: true)
                MetricView(title: "Nivel", value: "\(visibleLevelDB) dB", scalesValueToFit: true)
                MetricView(title: "Estado", value: recorder.isWritingAudio ? L("Guarda") : L("Espera"), scalesValueToFit: true)
            }

            VStack(spacing: 12) {
                DetailRow(title: "Calidad", value: settings.quality.title)
                DetailRow(title: "Corte", value: String(format: L("%d min"), settings.segmentMinutes))
                DetailRow(title: "Modo", value: displayedMode.title)
                if displayedMode == .soundActivated {
                    DetailRow(title: "Umbral", value: "\(visibleThresholdDB) dB")
                    DetailRow(title: "Extra", value: soundTailTitle(settings.soundTailSeconds))
                }
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
    }

    private var statusText: String {
        if recorder.isInterrupted {
            return L("Pausado por otro audio. Se reanudara automaticamente")
        }

        if recorder.isRecording, !recorder.isCapturingAudio {
            return recorder.lastError ?? L("No se pudo reanudar la grabacion.")
        }

        if recorder.isRecording {
            if displayedMode == .everything {
                return String(format: L("Se crea un archivo nuevo cada %d minutos"), settings.segmentMinutes)
            } else if recorder.isWritingAudio {
                return String(format: L("Supera %d dB y se esta guardando audio"), visibleThresholdDB)
            } else {
                return String(format: L("Esperando sonido suficiente (%d dB)"), visibleThresholdDB)
            }
        } else {
            return L("Toca el microfono para empezar")
        }
    }

    private var visibleLevelDB: Int {
        normalizedDB(recorder.currentLevel)
    }

    private var displayedMode: RecordingMode {
        recorder.activeRecordingMode ?? settings.mode
    }

    private var visibleThresholdDB: Int {
        normalizedDB(settings.recordingThresholdDB)
    }

    private func normalizedDB(_ dbFS: Float) -> Int {
        Int(round(min(max(dbFS + 80, 0), 70)))
    }

    private func toggleRecording() {
        if recorder.isRecording {
            recorder.stop()
        } else {
            Task {
                await recorder.start(settings: settings, library: library)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func soundTailTitle(_ seconds: Double) -> String {
        seconds == 0 ? L("No") : String(format: L("%.1f s"), seconds)
    }
}

private struct MetricView: View {
    let title: String
    let value: String
    let scalesValueToFit: Bool

    var body: some View {
        VStack(spacing: 6) {
            metricValue
            Text(L(title))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var metricValue: some View {
        if scalesValueToFit {
            Text(value)
                .font(.title2.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        } else {
            Text(value)
                .font(.title2.monospacedDigit().weight(.semibold))
        }
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(L(title))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
