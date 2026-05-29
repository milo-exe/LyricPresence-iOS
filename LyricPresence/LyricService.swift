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

    private var pollTask: Task<Void, Never>?
    private var lyricTask: Task<Void, Never>?
    private var lastTrackId: String?
    private var lyrics: [LyricLine] = []
    private var lastFetchTime: Date?
    private var lastProgressMs: Int = 0
    private var lastPlayedAt: Date?

    private var estimatedProgressMs: Int {
        guard let fetchTime = lastFetchTime else { return 0 }
        return lastProgressMs + Int(Date().timeIntervalSince(fetchTime) * 1000)
    }

    private var idleTimeoutMinutes: Int {
        let v = UserDefaults.standard.integer(forKey: "idleTimeoutMinutes")
        return v == 0 ? 5 : v
    }

    private func applyCase(_ text: String) -> String {
        switch UserDefaults.standard.string(forKey: "lyricsCase") ?? "lower" {
        case "upper": return text.uppercased()
        case "original": return text
        default: return text.lowercased()
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        errorMessage = nil
        startPolling()
    }

    func stop() {
        pollTask?.cancel()
        lyricTask?.cancel()
        pollTask = nil
        lyricTask = nil
        isRunning = false
        isPaused = false
        currentLyric = ""
        nextTrack = nil
        Task { await DiscordManager.shared.clearStatus() }
    }

    // MARK: - Spotify polling (every 3s for accurate progress sync)

    private func startPolling() {
        pollTask = Task {
            while !Task.isCancelled {
                await fetchTrack()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func fetchTrack() async {
        guard let track = await SpotifyManager.shared.fetchCurrentTrack() else {
            errorMessage = "Could not reach Spotify."
            if currentTrack != nil {
                currentTrack = nil
                nextTrack = nil
                currentLyric = ""
                lyricTask?.cancel()
                await DiscordManager.shared.clearStatus()
            }
            return
        }

        errorMessage = nil
        currentTrack = track

        if track.isPlaying {
            lastPlayedAt = Date()
        } else if let last = lastPlayedAt,
                  Date().timeIntervalSince(last) > Double(idleTimeoutMinutes * 60) {
            stop()
            return
        }

        if !track.isPlaying {
            if !isPaused {
                isPaused = true
                currentLyric = ""
                lyricTask?.cancel()
                await DiscordManager.shared.clearStatus()
            }
            return
        }

        if isPaused { isPaused = false }

        // Sync accurate progress from Spotify
        lastFetchTime = Date()
        lastProgressMs = track.progressMs

        if track.id != lastTrackId {
            lastTrackId = track.id
            lyrics = await LyricsManager.shared.lyrics(for: track)
            nextTrack = await SpotifyManager.shared.fetchNextInQueue()
            // Restart lyric timer for new track
            lyricTask?.cancel()
            scheduleLyrics()
        }
    }

    // MARK: - Lyric timer (fires at exact lyric timestamps)

    private func scheduleLyrics() {
        lyricTask = Task {
            while !Task.isCancelled {
                let progress = estimatedProgressMs

                if let line = LyricsManager.shared.currentLine(in: lyrics, at: progress),
                   !line.trimmingCharacters(in: .whitespaces).isEmpty,
                   line != currentLyric {
                    currentLyric = line
                    await DiscordManager.shared.setStatus(text: applyCase(line))
                } else if lyrics.isEmpty && currentLyric != "" {
                    currentLyric = ""
                    await DiscordManager.shared.clearStatus()
                }

                // Sleep until the exact next lyric line timestamp
                if let next = lyrics.first(where: { $0.timestampMs > estimatedProgressMs }) {
                    let delay = Double(next.timestampMs - estimatedProgressMs) / 1000.0
                    try? await Task.sleep(for: .seconds(max(0.05, delay)))
                } else {
                    // No more lyrics — wait for next Spotify poll to resync
                    try? await Task.sleep(for: .seconds(3))
                    break
                }
            }
        }
    }
}
