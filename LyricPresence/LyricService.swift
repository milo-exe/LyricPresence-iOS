import Foundation

@MainActor
class LyricService: ObservableObject {
    static let shared = LyricService()

    @Published var isRunning = false
    @Published var currentTrack: TrackInfo?
    @Published var nextTrack: TrackInfo?
    @Published var currentLyric: String = ""
    @Published var isPaused = false
    @Published var errorMessage: String?

    private var timer: Task<Void, Never>?
    private var lastTrackId: String?
    private var lyrics: [LyricLine] = []
    private var lastPlayedAt: Date?

    private var idleTimeoutMinutes: Int {
        UserDefaults.standard.integer(forKey: "idleTimeoutMinutes") == 0
            ? 5
            : UserDefaults.standard.integer(forKey: "idleTimeoutMinutes")
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        timer = Task {
            while !Task.isCancelled {
                await tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
        isPaused = false
        currentLyric = ""
        nextTrack = nil
        Task { await DiscordManager.shared.clearStatus() }
    }

    private func tick() async {
        guard let track = await SpotifyManager.shared.fetchCurrentTrack() else {
            errorMessage = "Could not reach Spotify. Check your connection or token."
            if currentTrack != nil {
                currentTrack = nil
                nextTrack = nil
                currentLyric = ""
                await DiscordManager.shared.clearStatus()
            }
            return
        }

        errorMessage = nil
        currentTrack = track

        // Idle timeout — stop if nothing has played for X minutes
        if track.isPlaying {
            lastPlayedAt = Date()
        } else if let last = lastPlayedAt,
                  Date().timeIntervalSince(last) > Double(idleTimeoutMinutes * 60) {
            stop()
            return
        }

        // Pause detection — clear status when paused
        if !track.isPlaying {
            if !isPaused {
                isPaused = true
                currentLyric = ""
                await DiscordManager.shared.clearStatus()
            }
            return
        }

        if isPaused { isPaused = false }

        // Fetch queue for next track preview
        if track.id != lastTrackId {
            lastTrackId = track.id
            lyrics = await LyricsManager.shared.lyrics(for: track)
            nextTrack = await SpotifyManager.shared.fetchNextInQueue()
        }

        // Update lyric
        if let line = LyricsManager.shared.currentLine(in: lyrics, at: track.progressMs),
           !line.trimmingCharacters(in: .whitespaces).isEmpty {
            if line != currentLyric {
                currentLyric = line
                await DiscordManager.shared.setStatus(text: line.lowercased())
            }
        } else if track.id != lastTrackId {
            // No lyrics found — show song name instead
            let fallback = "\(track.title) — \(track.artist)"
            if fallback != currentLyric {
                currentLyric = fallback
                await DiscordManager.shared.setStatus(text: fallback.lowercased())
            }
        }
    }
}
