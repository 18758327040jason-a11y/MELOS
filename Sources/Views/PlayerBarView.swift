import SwiftUI

// MARK: - Player Bar (Bottom)

struct PlayerBarView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        ZStack {
            // Frosted glass background
            VisualEffectView(material: .headerView, blendingMode: .withinWindow)
                .opacity(0.85)

            HStack(spacing: Theme.Spacing.xxl) {
                // Left: song info + album art
                SongInfoBlock()

                Spacer()

                // Center: playback controls
                PlaybackControls()

                Spacer()

                // Right: volume
                VolumeControl()
                    .frame(width: 120)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
        }
    }
}

// MARK: - Song Info Block

struct SongInfoBlock: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Album art
            AlbumArtView(
                url: playerVM.currentSong?.coverUrl,
                size: Theme.Sizes.albumArtSmall
            )

            // Title + artist
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if let song = playerVM.currentSong {
                    Text(song.title)
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        .foregroundColor(Theme.Palette.textPrimary)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: Theme.FontSize.caption))
                        .foregroundColor(Theme.Palette.textSecondary)
                        .lineLimit(1)
                } else {
                    Text("未播放")
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(Theme.Palette.textTertiary)
                    Text("")
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 240, alignment: .leading)
    }
}

// MARK: - Playback Controls

struct PlaybackControls: View {
    @EnvironmentObject var playerVM: PlayerViewModel

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
                            .fill(buttonActive ? Theme.Palette.accent : Theme.Palette.bgTertiary)
                            .frame(
                                width: Theme.Sizes.playButtonLarge,
                                height: Theme.Sizes.playButtonLarge
                            )

                        if playerVM.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        } else {
                            Image(systemName: buttonIcon)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: playerVM.playbackState == .playing ? 0 : 2)
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

    // 是否可点击
    private var buttonActive: Bool {
        playerVM.playbackState != .idle
    }

    // 显示哪个图标：idle/ready/failed → ▶，playing → ⏸
    private var buttonIcon: String {
        playerVM.playbackState == .playing ? "pause.fill" : "play.fill"
    }

    private func handlePlayButton() {
        switch playerVM.playbackState {
        case .playing:
            playerVM.togglePlayPause()
        case .ready, .idle:
            playerVM.startPlayback()
        case .failed:
            playerVM.startPlayback()
        }
    }
}

// MARK: - Control Button

struct ControlButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void
    let disabled: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundColor(disabled ? Theme.Palette.textTertiary : Theme.Palette.textSecondary)
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
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var isHovering = false

    var displayTime: Double { isDragging ? dragValue : playerVM.currentTime }
    var displayDuration: Double { isDragging ? dragValue : playerVM.duration }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: Theme.Spacing.xs) {
                // Track
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.Palette.progressBar)
                        .frame(height: 3)

                    // Filled
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.Palette.progressFill)
                        .frame(
                            width: progressWidth(in: geo),
                            height: 3
                        )

                    // Knob
                    if isDragging || isHovering {
                        Circle()
                            .fill(Theme.Palette.progressFill)
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

                // Time labels
                HStack {
                    Text(formatTime(displayTime))
                        .font(.system(size: Theme.FontSize.small, design: .monospaced))
                        .foregroundColor(Theme.Palette.textTertiary)
                    Spacer()
                    Text(formatTime(displayDuration))
                        .font(.system(size: Theme.FontSize.small, design: .monospaced))
                        .foregroundColor(Theme.Palette.textTertiary)
                }
            }
        }
        .frame(height: 36)
    }

    private func progressWidth(in geo: GeometryProxy) -> CGFloat {
        guard playerVM.duration > 0 else { return 0 }
        let ratio = displayTime / displayDuration
        return CGFloat(ratio) * geo.size.width
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
                .foregroundColor(Theme.Palette.volumeIcon)

            Slider(value: Binding(
                get: { playerVM.volume },
                set: { playerVM.setVolume($0) }
            ), in: 0...1)
            .tint(Theme.Palette.volumeFill)
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
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
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
            .fill(Theme.Palette.bgTertiary)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.3))
                    .foregroundColor(Theme.Palette.textTertiary)
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
