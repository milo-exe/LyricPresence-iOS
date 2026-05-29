import Foundation

class DiscordManager {
    static let shared = DiscordManager()

    private var token: String { UserDefaults.standard.string(forKey: "discordToken") ?? "" }
    private var prefix: String { UserDefaults.standard.string(forKey: "statusPrefix") ?? "♫" }
    private var emoji: String { UserDefaults.standard.string(forKey: "statusEmoji") ?? "" }

    func setStatus(text: String) async {
        let fullText = prefix.isEmpty ? text : "\(prefix) \(text)"
        var statusBody: [String: Any] = ["text": fullText]
        if !emoji.isEmpty { statusBody["emoji_name"] = emoji }
        await patch(body: ["custom_status": statusBody])
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
