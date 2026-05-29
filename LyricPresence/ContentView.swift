import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: LyricService
    @EnvironmentObject var spotify: SpotifyManager
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasOnboarded")

    var body: some View {
        TabView {
            NowPlayingView()
                .tabItem { Label("Now Playing", systemImage: "music.note") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .environmentObject(spotify)
        }
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var spotify: SpotifyManager
    @State private var page = 0
    @State private var clientId = UserDefaults.standard.string(forKey: "spotifyClientId") ?? ""
    @State private var discordToken = UserDefaults.standard.string(forKey: "discordToken") ?? ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $page) {
                // Page 1 — Welcome
                VStack(spacing: 20) {
                    Spacer()
                    Text("♫")
                        .font(.system(size: 72))
                    Text("LyricPresence")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Show your Spotify lyrics\nas your Discord status — live.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    Spacer()
                    Button("Get Started") { withAnimation { page = 1 } }
                        .buttonStyle(OnboardingButtonStyle())
                    Spacer().frame(height: 40)
                }
                .tag(0)

                // Page 2 — Spotify
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                    Text("Connect Spotify")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Enter your Spotify Client ID.\nGet one free at developer.spotify.com")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    TextField("Client ID", text: $clientId)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 32)
                        .onChange(of: clientId) {
                            UserDefaults.standard.set(clientId, forKey: "spotifyClientId")
                        }
                    if spotify.isAuthorized {
                        Label("Connected!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Connect Spotify") { spotify.authorize() }
                            .disabled(clientId.isEmpty)
                            .buttonStyle(OnboardingButtonStyle(color: .green))
                    }
                    Spacer()
                    Button("Next →") { withAnimation { page = 2 } }
                        .buttonStyle(OnboardingButtonStyle())
                    Spacer().frame(height: 40)
                }
                .tag(1)

                // Page 3 — Discord
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.indigo)
                    Text("Discord Token")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Open Discord in your browser → DevTools\n→ Network → any request → Authorization header.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    SecureField("Paste token here", text: $discordToken)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(.horizontal, 32)
                        .onChange(of: discordToken) {
                            UserDefaults.standard.set(discordToken, forKey: "discordToken")
                        }
                    Spacer()
                    Button("Done") {
                        UserDefaults.standard.set(true, forKey: "hasOnboarded")
                        isPresented = false
                    }
                    .buttonStyle(OnboardingButtonStyle())
                    Spacer().frame(height: 40)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
    }
}

struct OnboardingButtonStyle: ButtonStyle {
    var color: Color = .white
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .foregroundStyle(.black)
            .frame(width: 200, height: 48)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .clipShape(Capsule())
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
                    image.resizable().scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(white: 0.15))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.3))
                        )
                }
                .frame(width: 240, height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
                .animation(.spring(duration: 0.6), value: artUrl)

                Spacer().frame(height: 24)

                // Song info
                if let track = service.currentTrack {
                    Text(track.title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 4)

                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)

                    if service.isPaused {
                        Text("paused")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 2)
                    }
                } else {
                    Text(service.isRunning ? "Nothing playing" : "Tap start to begin")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer().frame(height: 20)

                // Error message
                if let error = service.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 8)
                }

                // Lyric rectangle
                Text(service.currentLyric.isEmpty ? "♫" : service.currentLyric)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .glassEffect(in: RoundedRectangle(cornerRadius: 16))
                    .animation(.easeInOut(duration: 0.3), value: service.currentLyric)

                Spacer().frame(height: 20)

                // Next up
                if let next = service.nextTrack {
                    HStack(spacing: 10) {
                        AsyncImage(url: URL(string: next.albumArtUrl ?? "")) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color(white: 0.2)
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next up")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.4))
                            Text("\(next.title) — \(next.artist)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                }

                Spacer().frame(height: 20)

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

                Spacer().frame(height: 12)

                Text("made by @kikq on discord")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.25))

                Spacer().frame(height: 32)
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var spotify: SpotifyManager
    @State private var clientId = UserDefaults.standard.string(forKey: "spotifyClientId") ?? ""
    @State private var discordToken = UserDefaults.standard.string(forKey: "discordToken") ?? ""
    @State private var statusPrefix = UserDefaults.standard.string(forKey: "statusPrefix") ?? "♫"
    @State private var statusEmoji = UserDefaults.standard.string(forKey: "statusEmoji") ?? ""
    @State private var idleTimeout = UserDefaults.standard.integer(forKey: "idleTimeoutMinutes") == 0 ? 5 : UserDefaults.standard.integer(forKey: "idleTimeoutMinutes")

    let emojiOptions = ["", "🎵", "🎶", "🎸", "🎤", "🎧", "🎼", "🎹", "🪗", "🎺", "🥁"]

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
                    Text("DevTools → Network → any request → Authorization header.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Status Appearance") {
                    HStack {
                        Text("Prefix")
                        Spacer()
                        TextField("♫", text: $statusPrefix)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: statusPrefix) {
                                UserDefaults.standard.set(statusPrefix, forKey: "statusPrefix")
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emoji")
                            .font(.body)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(emojiOptions, id: \.self) { emoji in
                                    Text(emoji.isEmpty ? "None" : emoji)
                                        .font(emoji.isEmpty ? .caption : .title2)
                                        .frame(width: 44, height: 44)
                                        .background(statusEmoji == emoji ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .onTapGesture {
                                            statusEmoji = emoji
                                            UserDefaults.standard.set(emoji, forKey: "statusEmoji")
                                        }
                                }
                            }
                        }
                    }

                    HStack {
                        Text("Preview")
                        Spacer()
                        Text("\(statusEmoji.isEmpty ? "" : statusEmoji + " ")\(statusPrefix) current lyric")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }

                Section("Behaviour") {
                    Stepper("Idle timeout: \(idleTimeout) min", value: $idleTimeout, in: 1...60) {
                        UserDefaults.standard.set(idleTimeout, forKey: "idleTimeoutMinutes")
                    }
                    Text("Auto-stops if nothing plays for \(idleTimeout) minutes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
