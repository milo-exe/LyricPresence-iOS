import Foundation

class DiscordManager {
    static let shared = DiscordManager()

    private var token: String { UserDefaults.standard.string(forKey: "discordToken") ?? "" }

    func setStatus(text: String) async {
        await patch(body: ["custom_status": ["text": "♫ \(text)", "emoji_name": NSNull()]])
    }

    func clearStatus() async {
        await patch(body: ["custom_status": NSNull()])
    }

    private func patch(body: [String: Any]) async {
        guard !token.isEmpty else { return }
        var req = URLRequest(url: URL(string: "https://discord.com/api/v9/users/@me/settings")!)
        req.httpMethod = "PATCH"
        req.setValue(token, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        _ = try? await URLSession.shared.data(for: req)
    }
}
