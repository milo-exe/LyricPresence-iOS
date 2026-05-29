import Foundation

@MainActor
class LyricService: ObservableObject {
    static let shared = LyricService()

    @Published var isRunning = false
    @Published var currentTrack: TrackInfo?
    @Published var currentLyric: String = ""

    private var timer: Task<Void, Never>?
    private var lastTrackId: String?
    private var lyrics: [LyricLine] = []

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Task {
            while !Task.isCancelled {
                await tick()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
        currentLyric = ""
        Task { await DiscordManager.shared.clearStatus() }
    }

    private func tick() async {
        guard let track = await SpotifyManager.shared.fetchCurrentTrack() else {
            if currentTrack != nil {
                currentTrack = nil
                currentLyric = ""
                await DiscordManager.shared.clearStatus()
            }
            return
        }

        currentTrack = track

        if track.id != lastTrackId {
            lastTrackId = track.id
            lyrics = await LyricsManager.shared.lyrics(for: track)
        }

        guard track.isPlaying else { return }

        if let line = LyricsManager.shared.currentLine(in: lyrics, at: track.progressMs) {
            if line != currentLyric {
                currentLyric = line
                await DiscordManager.shared.setStatus(text: line)
            }
        }
    }
}
