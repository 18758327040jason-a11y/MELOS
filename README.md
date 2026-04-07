# 🎵 MELOS

> YouTube / SoundCloud / NetEase Music Player for macOS

MELOS is a native macOS music player that fetches and plays audio from YouTube, SoundCloud, and NetEase Music, with local download support.

## Features

- 🔍 **Multi-Platform Search** — YouTube Music, SoundCloud, NetEase Cloud Music
- ⬇️ **One-Click Download** — Download tracks locally for offline playback
- 🎛️ **Dual Playback Engine** — AVAudioPlayer (local) + AVPlayer (streaming)
- 🎹 **Space Bar Play/Pause** — Keyboard shortcut support
- 📊 **Progress Bar** — Hover to preview duration, drag to seek
- 🔊 **Volume Slider** — Hover to reveal, smooth opacity transition
- 🌙 **Dark Mode** — Full dark mode UI
- 💚 **Download Indicator** — Green badge on downloaded tracks
- 🏆 **Favorites** — Mark and manage favorite tracks
- 📝 **Lyrics** — In-app lyrics display
- 🎧 **Queue & History** — Manage playback queue and history

## Tech Stack

- **Swift 5.9** + **SwiftUI**
- **AVFoundation** — Audio playback
- **yt-dlp** — YouTube/SoundCloud metadata extraction
- **AFNetworking** — Network requests

## Build

```bash
cd ~/Documents/program/MusicPlayer
xcodebuild -project MELOS.xcodeproj -scheme MusicPlayer -configuration Debug build
```

Then open `~/Library/Developer/Xcode/DerivedData/MELOS-*/Build/Products/Debug/MELOS.app`

## Project Structure

```
Sources/
├── AppDelegate.swift          # App lifecycle + space bar handler
├── MELOSApp.swift             # SwiftUI App entry
├── Models/                    # Data models
├── ViewModels/                # PlayerViewModel, PlaylistViewModel
├── Views/                     # SwiftUI views
│   ├── ContentView.swift      # Main layout
│   ├── PlayerBarView.swift    # Playback controls + progress + volume
│   ├── SongListView.swift     # Track list
│   └── DownloadSheet.swift    # Download panel
├── Services/
│   ├── AudioPlayerService.swift   # Dual engine audio playback
│   ├── DownloadService.swift      # Local file management
│   ├── YouTubeMusicService.swift  # YouTube metadata
│   ├── SoundCloudService.swift   # SoundCloud metadata
│   └── NetEaseService.swift       # NetEase metadata
└── Utilities/                 # Extensions, theme, database
```

## License

MIT
