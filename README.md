# LyricPresence iOS

Displays your Spotify lyrics in real-time on your Discord custom status — running fully in the background on iOS.

A mobile port of [LyricPresence](https://github.com/milo-exe/LyricPresence) by milo-exe.

---

## How it Works

- Reads your current Spotify playback via the Spotify Web API
- Fetches time-synced lyrics from [LRCLIB](https://lrclib.net)
- Updates your Discord custom status line-by-line as the song plays
- Stays alive in the background using a silent audio session

---

## Requirements

- iPhone running iOS 16 or later
- Spotify account
- Discord account
- A signing certificate (e.g. DXSign) to sideload the IPA

---

## Setup

**1. Get a Spotify Client ID**

Go to [developer.spotify.com](https://developer.spotify.com), create an app, and add the following redirect URI:

```
lyricpresence://callback
```

Copy your **Client ID**.

**2. Get your Discord token**

Open Discord in your browser → open DevTools (F12) → go to **Network** → send any message → find a request with an `Authorization` header. Copy that value.

> ⚠️ Never share your Discord token. Anyone with it has full access to your account.

**3. Build the IPA**

Download the latest IPA from the [Actions](../../actions) tab (most recent successful run → **Artifacts → LyricPresence**), or build it yourself by forking this repo — GitHub Actions builds it automatically on every push.

**4. Install**

Sign the IPA with your certificate and install it on your device.

**5. Configure the app**

Open LyricPresence → go to **Settings**:
- Enter your Spotify Client ID and tap **Connect Spotify**
- Paste your Discord token

Then go to **Now Playing** and tap **Start**.

---

## Notes

- Lyrics are sourced from LRCLIB. If no synced lyrics are found, the Discord status won't update for that song.
- The app uses a silent background audio session to stay alive — this is standard practice for iOS background apps.
- Updating Discord status with a user token is against Discord's ToS. Use at your own risk.

---

## Troubleshooting

**Status stops updating after a while**
Make sure the app is not force-closed. iOS may still suspend it under heavy memory pressure — reopen and tap Start again.

**"Nothing playing" even though Spotify is running**
Make sure Spotify is actively playing (not paused) and that you've granted the correct Spotify API scopes during login.

**Discord status not changing**
Double-check your Discord token — tokens expire if you change your password or log out of all devices.
