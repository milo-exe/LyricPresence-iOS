import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: LyricService
    @EnvironmentObject var spotify: SpotifyManager

    var body: some View {
        TabView {
            NowPlayingView()
                .tabItem { Label("Now Playing", systemImage: "music.note") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Now Playing

struct NowPlayingView: View {
    @EnvironmentObject var service: LyricService
    @EnvironmentObject var spotify: SpotifyManager

    var artUrl: URL? {
        guard let s = service.currentTrack?.albumArtUrl else { return nil }
        return URL(string: s)
    }

    var body: some View {
        ZStack {
            // Blurred art background
            AsyncImage(url: artUrl) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color(white: 0.08)
            }
            .ignoresSafeArea()
            .blur(radius: 60)
            .scaleEffect(1.2)
            .overlay(Color.black.opacity(0.55))
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1), value: artUrl)

            VStack(spacing: 0) {
                Spacer()

                // Album art
                AsyncImage(url: artUrl) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(white: 0.15))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.3))
                        )
                }
                .frame(width: 260, height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
                .animation(.spring(duration: 0.6), value: artUrl)

                Spacer().frame(height: 32)

                // Song info
                if let track = service.currentTrack {
                    Text(track.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .padding(.horizontal, 32)
                        .transition(.opacity)

                    Spacer().frame(height: 4)

                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .transition(.opacity)
                } else {
                    Text(service.isRunning ? "Nothing playing" : "Tap start to begin")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer().frame(height: 28)

                // Lyric pill
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .frame(height: 64)

                    Text(service.currentLyric.isEmpty ? "♫" : service.currentLyric)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 20)
                        .animation(.easeInOut(duration: 0.3), value: service.currentLyric)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 36)

                // Start / Stop button
                Button {
                    if service.isRunning { service.stop() } else { service.start() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: service.isRunning ? "stop.fill" : "play.fill")
                        Text(service.isRunning ? "Stop" : "Start")
                            .fontWeight(.semibold)
                    }
                    .frame(width: 140, height: 50)
                    .background(service.isRunning ? Color.red.opacity(0.85) : Color.white.opacity(0.15))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
                }
                .disabled(!spotify.isAuthorized)
                .animation(.easeInOut(duration: 0.2), value: service.isRunning)

                Spacer().frame(height: 48)
            }
        }
    }
}

// MARK: - Settings

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
                    Text("Find your token in Discord's web app → DevTools → Network → any request → Authorization header.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
