import Foundation

struct LyricLine {
    let timestampMs: Int
    let text: String
}

class LyricsManager {
    static let shared = LyricsManager()

    private var cachedTrackId: String?
    private var cachedLines: [LyricLine] = []

    func lyrics(for track: TrackInfo) async -> [LyricLine] {
        if track.id == cachedTrackId { return cachedLines }

        let durationSeconds = track.durationMs / 1000
        let artist = track.artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let title = track.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let album = track.album.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "https://lrclib.net/api/get?artist_name=\(artist)&track_name=\(title)&album_name=\(album)&duration=\(durationSeconds)")!

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let synced = json["syncedLyrics"] as? String
        else { return [] }

        let lines = parseLRC(synced)
        cachedTrackId = track.id
        cachedLines = lines
        return lines
    }

    func currentLine(in lines: [LyricLine], at progressMs: Int) -> String? {
        var result: LyricLine?
        for line in lines {
            if line.timestampMs <= progressMs { result = line }
            else { break }
        }
        return result?.text.isEmpty == false ? result?.text : nil
    }

    private func parseLRC(_ lrc: String) -> [LyricLine] {
        let pattern = #/\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)/#
        return lrc.components(separatedBy: "\n").compactMap { line in
            guard let match = try? pattern.firstMatch(in: line) else { return nil }
            let min = Int(match.1)!
            let sec = Int(match.2)!
            let ms: Int
            let msStr = String(match.3)
            ms = msStr.count == 2 ? Int(msStr)! * 10 : Int(msStr)!
            let text = String(match.4).trimmingCharacters(in: .whitespaces)
            return LyricLine(timestampMs: (min * 60 + sec) * 1000 + ms, text: text)
        }.sorted { $0.timestampMs < $1.timestampMs }
    }
}
