import Foundation
import CryptoKit
import UIKit

struct TrackInfo: Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let durationMs: Int
    let progressMs: Int
    let isPlaying: Bool
    let albumArtUrl: String?
}

class SpotifyManager: ObservableObject {
    static let shared = SpotifyManager()

    @Published var isAuthorized = false
    @Published var currentTrack: TrackInfo?

    private var clientId: String { UserDefaults.standard.string(forKey: "spotifyClientId") ?? "" }
    private let redirectUri = "lyricpresence://callback"
    private let scopes = "user-read-currently-playing user-read-playback-state"

    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "spotifyAccessToken") }
        set { UserDefaults.standard.set(newValue, forKey: "spotifyAccessToken") }
    }
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "spotifyRefreshToken") }
        set { UserDefaults.standard.set(newValue, forKey: "spotifyRefreshToken") }
    }
    private var tokenExpiry: Date? {
        get { UserDefaults.standard.object(forKey: "spotifyTokenExpiry") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "spotifyTokenExpiry") }
    }
    private var codeVerifier: String?

    init() {
        isAuthorized = refreshToken != nil
    }

    func authorize() {
        let verifier = generateCodeVerifier()
        codeVerifier = verifier
        let challenge = generateCodeChallenge(from: verifier)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        components.queryItems = [
            .init(name: "client_id", value: clientId),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: redirectUri),
            .init(name: "scope", value: scopes),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
        ]
        UIApplication.shared.open(components.url!)
    }

    func handleCallback(url: URL) {
        guard url.scheme == "lyricpresence",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let verifier = codeVerifier else { return }
        Task { await exchangeCode(code, verifier: verifier) }
    }

    func fetchCurrentTrack() async -> TrackInfo? {
        guard await ensureValidToken() else { return nil }
        guard let token = accessToken else { return nil }

        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let item = json["item"] as? [String: Any],
              let id = item["id"] as? String,
              let name = item["name"] as? String,
              let artists = item["artists"] as? [[String: Any]],
              let artist = artists.first?["name"] as? String,
              let albumObj = item["album"] as? [String: Any],
              let album = albumObj["name"] as? String,
              let duration = item["duration_ms"] as? Int,
              let progress = json["progress_ms"] as? Int,
              let isPlaying = json["is_playing"] as? Bool
        else { return nil }

        let albumArtUrl = (albumObj["images"] as? [[String: Any]])?.first?["url"] as? String

        return TrackInfo(id: id, title: name, artist: artist, album: album,
                         durationMs: duration, progressMs: progress, isPlaying: isPlaying,
                         albumArtUrl: albumArtUrl)
    }

    func fetchNextInQueue() async -> TrackInfo? {
        guard await ensureValidToken(), let token = accessToken else { return nil }
        var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/queue")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let queue = json["queue"] as? [[String: Any]],
              let item = queue.first,
              let id = item["id"] as? String,
              let name = item["name"] as? String,
              let artists = item["artists"] as? [[String: Any]],
              let artist = artists.first?["name"] as? String,
              let albumObj = item["album"] as? [String: Any],
              let album = albumObj["name"] as? String,
              let duration = item["duration_ms"] as? Int
        else { return nil }
        let imageUrl = (albumObj["images"] as? [[String: Any]])?.first?["url"] as? String
        return TrackInfo(id: id, title: name, artist: artist, album: album,
                         durationMs: duration, progressMs: 0, isPlaying: false, albumArtUrl: imageUrl)
    }

    func logout() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry = nil
        isAuthorized = false
    }

    // MARK: - Private

    private func exchangeCode(_ code: String, verifier: String) async {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=authorization_code&code=\(code)&redirect_uri=\(redirectUri)&client_id=\(clientId)&code_verifier=\(verifier)"
        req.httpBody = body.data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let expiresIn = json["expires_in"] as? Int
        else { return }

        accessToken = access
        refreshToken = refresh
        tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        await MainActor.run { isAuthorized = true }
    }

    private func ensureValidToken() async -> Bool {
        if let expiry = tokenExpiry, expiry > Date(), accessToken != nil { return true }
        guard let refresh = refreshToken else { return false }

        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "grant_type=refresh_token&refresh_token=\(refresh)&client_id=\(clientId)"
        req.httpBody = body.data(using: .utf8)

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String,
              let expiresIn = json["expires_in"] as? Int
        else { return false }

        accessToken = access
        tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        if let newRefresh = json["refresh_token"] as? String { refreshToken = newRefresh }
        return true
    }

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
