import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: LyricService
    @EnvironmentObject var spotify: SpotifyManager

    var body: some View {
        TabView {
            StatusView()
                .tabItem { Label("Now Playing", systemImage: "music.note") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

struct StatusView: View {
    @EnvironmentObject var service: LyricService
    @EnvironmentObject var spotify: SpotifyManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if let track = service.currentTrack {
                VStack(spacing: 6) {
                    Text(track.title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(track.artist)
                        .foregroundStyle(.secondary)
                }

                if !service.currentLyric.isEmpty {
                    Text(service.currentLyric)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal)
                        .transition(.opacity)
                        .animation(.easeInOut, value: service.currentLyric)
                } else {
                    Text("No synced lyrics available")
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text(service.isRunning ? "Nothing playing" : "Tap Start to begin")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(service.isRunning ? "Stop" : "Start") {
                if service.isRunning { service.stop() } else { service.start() }
            }
            .buttonStyle(.borderedProminent)
            .tint(service.isRunning ? .red : .green)
            .disabled(!spotify.isAuthorized)
            .padding(.bottom, 32)
        }
        .padding()
    }
}

struct SettingsView: View {
    @EnvironmentObject var spotify: SpotifyManager
    @State private var clientId = UserDefaults.standard.string(forKey: "spotifyClientId") ?? ""
    @State private var discordToken = UserDefaults.standard.string(forKey: "discordToken") ?? ""

    var body: some View {
        NavigationView {
            Form {
                Section("Spotify") {
                    TextField("Client ID", text: $clientId)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: clientId) {
                            UserDefaults.standard.set(clientId, forKey: "spotifyClientId")
                        }

                    if spotify.isAuthorized {
                        HStack {
                            Text("Connected")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                        Button("Log out", role: .destructive) { spotify.logout() }
                    } else {
                        Button("Connect Spotify") { spotify.authorize() }
                            .disabled(clientId.isEmpty)
                    }
                }

                Section("Discord") {
                    SecureField("User Token", text: $discordToken)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: discordToken) {
                            UserDefaults.standard.set(discordToken, forKey: "discordToken")
                        }
                    Text("Find your token in Discord's web app via DevTools → Application → Local Storage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
