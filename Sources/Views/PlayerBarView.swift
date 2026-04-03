import SwiftUI

// MARK: - Player Bar (Bottom)

struct PlayerBarView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        VStack(spacing: 0) {
            if playerVM.isMiniPlayer {
                MiniPlayerView()
            } else {
                fullPlayerBar
            }
        }
    }

    private var fullPlayerBar: some View {
        ZStack {
            // Frosted glass background
            VisualEffectView(material: .headerView, blendingMode: .withinWindow)
                .opacity(0.85)

            HStack(spacing: Theme.Spacing.xxl) {
                // Left: song info + album art + favorite
                SongInfoBlock()

                Spacer()

                // Center: playback controls
                PlaybackControls()

                Spacer()

                // Right: volume + panel toggles
                HStack(spacing: Theme.Spacing.lg) {
                    // Panel toggles
                    PanelToggle(panel: .lyrics)
                    PanelToggle(panel: .queue)
                    PanelToggle(panel: .history)

                    Divider()
                        .frame(height: 20)
                        .background(tc.divider)

                    // Mini player toggle
                    Button(action: { playerVM.isMiniPlayer = true }) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 11))
                            .foregroundColor(tc.textTertiary)
                    }
                    .buttonStyle(.plain)

                    VolumeControl()
                        .frame(width: 120)
                }
            }
            .padding(.horizontal, Theme.Spacing.xxl)
        }
        .frame(height: Theme.Sizes.playerBarHeight)
    }
}

// MARK: - Panel Toggle Button

struct PanelToggle: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc
    let panel: RightPanelType

    var isActive: Bool { playerVM.rightPanel == panel }

    var body: some View {
        Button(action: {
            withAnimation(Theme.Anim.fast) {
                playerVM.rightPanel = isActive ? .none : panel
            }
        }) {
            Image(systemName: panel.icon)
                .font(.system(size: 13))
                .foregroundColor(isActive ? tc.accent : tc.textTertiary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Song Info Block

struct SongInfoBlock: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Album art
            AlbumArtView(url: playerVM.currentSong?.coverUrl, size: Theme.Sizes.albumArtSmall)

            // Title + artist
            VStack(alignment: .leading, spacing: 2) {
                if let song = playerVM.currentSong {
                    Text(song.title)
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        .foregroundColor(tc.textPrimary)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(tc.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("未播放")
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(tc.textTertiary)
                    Text("")
                }
            }
            .frame(width: 180, alignment: .leading)

            // Favorite button
            if playerVM.currentSong != nil {
                Button(action: { playerVM.toggleFavorite() }) {
                    Image(systemName: (playerVM.currentSong?.isFavorite ?? false) ? "heart.fill" : "heart")
                        .font(.system(size: 14))
                        .foregroundColor((playerVM.currentSong?.isFavorite ?? false) ? Color(hex: "EA4335") : tc.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .frame(width: 280, alignment: .leading)
    }
}

// MARK: - Playback Controls

struct PlaybackControls: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Buttons
            HStack(spacing: Theme.Spacing.xl) {
                // Previous
                ControlButton(
                    icon: "backward.fill",
                    size: 15,
                    action: { playerVM.playPrevious() },
                    disabled: playerVM.currentSong == nil
                )

                // Play / Pause — large
                Button(action: { handlePlayButton() }) {
                    ZStack {
                        Circle()
                            .fill(buttonActive ? tc.accent : tc.bgTertiary)
                            .frame(width: Theme.Sizes.playButtonLarge, height: Theme.Sizes.playButtonLarge)

                        if playerVM.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        } else {
                            Image(systemName: buttonIcon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!buttonActive)

                // Next
                ControlButton(
                    icon: "forward.fill",
                    size: 15,
                    action: { playerVM.playNext() },
                    disabled: playerVM.currentSong == nil
                )

                // Play mode
                ControlButton(
                    icon: playerVM.playMode.icon,
                    size: 12,
                    action: { playerVM.cyclePlayMode() },
                    disabled: false
                )
            }

            ProgressBar()
        }
        .alert("播放失败", isPresented: Binding(
            get: { playerVM.playbackError != nil },
            set: { if !$0 { playerVM.dismissError() } }
        )) {
            Button("确定") { playerVM.dismissError() }
        } message: {
            Text(playerVM.playbackError ?? "")
        }
    }

    private var buttonActive: Bool { playerVM.playbackState != .idle }
    private var buttonIcon: String {
        playerVM.playbackState == .playing ? "pause.fill" : "play.fill"
    }

    private func handlePlayButton() {
        switch playerVM.playbackState {
        case .playing: playerVM.togglePlayPause()
        case .ready, .idle, .failed: playerVM.startPlayback()
        }
    }
}

// MARK: - Control Button

struct ControlButton: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc
    let icon: String
    let size: CGFloat
    let action: () -> Void
    let disabled: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(disabled ? tc.textTertiary : tc.textSecondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .contentShape(Rectangle())
    }
}

// MARK: - Progress Bar

struct ProgressBar: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var isHovering = false

    var displayTime: Double { isDragging ? dragValue : playerVM.currentTime }
    var displayDuration: Double { isDragging ? dragValue : playerVM.duration }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: Theme.Spacing.xs) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tc.progressBar)
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(tc.progressFill)
                        .frame(width: progressWidth(in: geo), height: 3)

                    if isDragging || isHovering {
                        Circle()
                            .fill(tc.progressFill)
                            .frame(width: 12, height: 12)
                            .offset(x: progressWidth(in: geo) - 6)
                            .animation(Theme.Anim.fast, value: isDragging)
                    }
                }
                .frame(height: 16)
                .contentShape(Rectangle())
                .onHover { isHovering = $0 }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let ratio = min(max(value.location.x / geo.size.width, 0), 1)
                            dragValue = ratio * playerVM.duration
                        }
                        .onEnded { value in
                            let ratio = min(max(value.location.x / geo.size.width, 0), 1)
                            playerVM.seek(to: ratio * playerVM.duration)
                            isDragging = false
                        }
                )

                HStack {
                    Text(formatTime(displayTime))
                        .font(.system(size: Theme.FontSize.small, design: .monospaced))
                        .foregroundColor(tc.textTertiary)
                    Spacer()
                    Text(formatTime(displayDuration))
                        .font(.system(size: Theme.FontSize.small, design: .monospaced))
                        .foregroundColor(tc.textTertiary)
                }
            }
        }
        .frame(height: 36)
    }

    private func progressWidth(in geo: GeometryProxy) -> CGFloat {
        guard playerVM.duration > 0 else { return 0 }
        return CGFloat(displayTime / displayDuration) * geo.size.width
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Volume Control

struct VolumeControl: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc

    var volumeIcon: String {
        if playerVM.volume == 0 { return "speaker.slash.fill" }
        if playerVM.volume < 0.33 { return "speaker.wave.1.fill" }
        if playerVM.volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: volumeIcon)
                .font(.system(size: 12))
                .foregroundColor(tc.volumeIcon)

            Slider(value: Binding(
                get: { playerVM.volume },
                set: { playerVM.setVolume($0) }
            ), in: 0...1)
            .tint(tc.volumeFill)
        }
    }
}

// MARK: - Album Art

struct AlbumArtView: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let urlString = url, let u = URL(string: urlString) {
                AsyncImage(url: u) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    PlaceholderView()
                }
            } else {
                PlaceholderView()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xs))
    }

    private func PlaceholderView() -> some View {
        RoundedRectangle(cornerRadius: Theme.Radius.xs)
            .fill(Color(hex: "F1F3F4"))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.3))
                    .foregroundColor(Color(hex: "9AA0A6"))
            )
    }
}

// MARK: - Visual Effect

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
