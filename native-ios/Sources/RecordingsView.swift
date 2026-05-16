import SwiftUI

struct RecordingsView: View {
    @EnvironmentObject private var library: RecordingLibrary
    @EnvironmentObject private var uploadQueue: CloudUploadQueue
    @EnvironmentObject private var playback: AudioPlaybackService

    @State private var shareItem: ShareItem?
    @State private var renameItem: RecordingItem?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                if library.items.isEmpty {
                    EmptyRecordingsView()
                } else {
                    ForEach(library.items) { item in
                        RecordingRow(
                            item: item,
                            onShare: { shareItem = ShareItem(url: item.fileURL) },
                            onRename: {
                                renameItem = item
                                renameText = item.title
                            },
                            onDelete: { delete(item) }
                        )
                            .environmentObject(playback)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            delete(library.items[index])
                        }
                    }
                }
            }
            .navigationTitle("Archivos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await uploadQueue.processNext()
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle")
                    }
                    .accessibilityLabel("Procesar subida")
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(url: item.url)
            }
            .alert("Cambiar nombre", isPresented: renameBinding) {
                TextField("Nombre", text: $renameText)
                Button("Cancelar", role: .cancel) {
                    renameItem = nil
                }
                Button("Guardar") {
                    guard let renameItem else { return }
                    Task {
                        await library.rename(renameItem, to: renameText)
                        self.renameItem = nil
                    }
                }
            } message: {
                Text("Se renombrara tambien el archivo de audio.")
            }
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renameItem != nil },
            set: { if !$0 { renameItem = nil } }
        )
    }

    private func delete(_ item: RecordingItem) {
        playback.stop()
        Task {
            await uploadQueue.removeJobs(recordingID: item.id)
            await library.delete(item)
        }
    }
}

private struct EmptyRecordingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("Sin grabaciones")
                .font(.headline)
            Text("Los segmentos apareceran aqui cuando termines de grabar.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

private struct RecordingRow: View {
    @EnvironmentObject private var playback: AudioPlaybackService

    let item: RecordingItem
    let onShare: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                playback.toggle(item)
            } label: {
                Image(systemName: playback.playingID == item.id ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(playback.playingID == item.id ? "Parar audio" : "Escuchar audio")

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                    Spacer()
                    Text(item.uploadState.title)
                        .font(.caption)
                        .foregroundStyle(color)
                }

                HStack(spacing: 12) {
                    Label(formatDuration(item.duration), systemImage: "clock")
                    Label(item.fileSizeText, systemImage: "internaldrive")
                    Label(item.mode.title, systemImage: "slider.horizontal.2.square")
                    Label(item.quality.title, systemImage: "speaker.wave.2")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(item.fileURL.lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                onShare()
            } label: {
                Label("Enviar", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)

            Button {
                onRename()
            } label: {
                Label("Renombrar", systemImage: "pencil")
            }
            .tint(.orange)
        }
        .contextMenu {
            Button {
                onShare()
            } label: {
                Label("Enviar", systemImage: "square.and.arrow.up")
            }

            Button {
                onRename()
            } label: {
                Label("Renombrar", systemImage: "pencil")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    private var color: Color {
        switch item.uploadState {
        case .uploaded: .green
        case .failed: .red
        case .queued, .uploading: .orange
        case .localOnly: .secondary
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
