import SwiftUI

@main
struct LyricPresenceApp: App {
    @StateObject private var service = LyricService.shared
    @StateObject private var spotify = SpotifyManager.shared

    init() {
        BackgroundAudioManager.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(service)
                .environmentObject(spotify)
                .onOpenURL { url in
                    spotify.handleCallback(url: url)
                }
        }
    }
}
