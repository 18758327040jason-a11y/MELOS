import SwiftUI

// MARK: - Player Bar — NetEase Music Style

struct PlayerBarView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        if playerVM.isMiniPlayer {
            MiniPlayerView()
        } else {
            fullPlayerBar
        }
    }

    // MARK: - Full Player Bar

    private var fullPlayerBar: some View {
        ZStack(alignment: .top) {
            // Solid background fills entire bar
            Rectangle()
                .fill(tc.bgSecondary)

            VStack(alignment: .leading, spacing: 0) {
                // Progress bar — sits at the very top edge
                NetEaseProgressBar()
                    .frame(maxWidth: .infinity)

                // Controls row (bottom)
                HStack(spacing: 0) {
                    // LEFT: album art + song info
                    HStack(spacing: Theme.Spacing.md) {
                        AlbumArtView(url: playerVM.currentSong?.coverUrl, size: 42)
                            .cornerRadius(Theme.Radius.xs)

                        VStack(alignment: .leading, spacing: 2) {
                            if let song = playerVM.currentSong {
                                Text(song.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(tc.textPrimary)
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(.system(size: 11))
                                    .foregroundColor(tc.textSecondary)
                                    .lineLimit(1)
                            } else {
                                Text("未播放")
                                    .font(.system(size: 13))
                                    .foregroundColor(tc.textTertiary)
                                Text("")
                            }
                        }
                    }
                    .frame(width: 220, alignment: .leading)

                    Spacer()

                    // CENTER: playback buttons
                    HStack(spacing: 28) {
                        Button(action: { playerVM.playPrevious() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 16))
                                .foregroundColor(playerVM.currentSong == nil ? tc.textTertiary : tc.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(playerVM.currentSong == nil)

                        Button(action: { handlePlayButton() }) {
                            ZStack {
                                Circle()
                                    .fill(tc.accent)
                                    .frame(width: 40, height: 40)
                                if playerVM.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.55)
                                        .tint(.white)
                                } else {
                                    Image(systemName: playerVM.playbackState == .playing ? "pause.fill" : "play.fill")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(playerVM.currentSong == nil && playerVM.playbackState == .idle)

                        Button(action: { playerVM.playNext() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 16))
                                .foregroundColor(playerVM.currentSong == nil ? tc.textTertiary : tc.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .disabled(playerVM.currentSong == nil)

                        // Like button
                        Button(action: {}) {
                            Image(systemName: "heart")
                                .font(.system(size: 13))
                                .foregroundColor(tc.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 280)

                    Spacer()

                    // RIGHT: volume + actions
                    HStack(spacing: Theme.Spacing.md) {
                        // Volume
                        HoverVolumeSlider()

                        Divider().frame(height: 16).background(tc.divider)

                        // Queue
                        Button(action: {
                            withAnimation(Theme.Anim.fast) {
                                playerVM.rightPanel = (playerVM.rightPanel == .queue) ? .none : .queue
                            }
                        }) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 13))
                                .foregroundColor(playerVM.rightPanel == .queue ? tc.accent : tc.textTertiary)
                        }
                        .buttonStyle(.plain)

                        // Lyrics
                        Button(action: {
                            withAnimation(Theme.Anim.fast) {
                                playerVM.rightPanel = (playerVM.rightPanel == .lyrics) ? .none : .lyrics
                            }
                        }) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 13))
                                .foregroundColor(playerVM.rightPanel == .lyrics ? tc.accent : tc.textTertiary)
                        }
                        .buttonStyle(.plain)

                        // Mini mode
                        Button(action: { playerVM.isMiniPlayer = true }) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 11))
                                .foregroundColor(tc.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 220)
                }
                .padding(.horizontal, 20)
                .frame(height: 56)
            }
        }
        .frame(height: 88)
        .alert("播放失败", isPresented: Binding(
            get: { playerVM.playbackError != nil },
            set: { if !$0 { playerVM.dismissError() } }
        )) {
            Button("确定") { playerVM.dismissError() }
        } message: {
            Text(playerVM.playbackError ?? "")
        }
    }

    private var volumeIcon: String {
        if playerVM.volume == 0 { return "speaker.slash.fill" }
        if playerVM.volume < 0.33 { return "speaker.wave.1.fill" }
        if playerVM.volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func handlePlayButton() {
        if playerVM.playbackState == .playing {
            playerVM.togglePlayPause()
        } else {
            playerVM.startPlayback()
        }
    }
}

// MARK: - Progress Bar (NetEase style: current |────●────| total)

struct NetEaseProgressBar: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc
    @State private var isDragging = false
    @State private var isHovering = false
    @State private var dragValue: Double = 0

    private var displayTime: Double { isDragging ? dragValue : playerVM.currentTime }
    private var displayDuration: Double { playerVM.duration }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(tc.progressBar)
                    .frame(height: isDragging || isHovering ? 4 : 3)

                // Filled portion
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(tc.progressFill)
                    .frame(width: max(0, progressWidth(in: geo)), height: isDragging || isHovering ? 4 : 3)

                // Thumb — only visible on hover or drag
                Circle()
                    .fill(Color.white)
                    .frame(width: isDragging || isHovering ? 12 : 0)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .offset(x: progressWidth(in: geo) - (isDragging || isHovering ? 6 : 0))
                    .animation(.easeOut(duration: 0.1), value: isHovering)
            }
            .frame(height: 20)
            .overlay(alignment: .trailing) {
                if isHovering || isDragging {
                    Text(formatTime(displayDuration))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(tc.textSecondary)
                        .padding(.trailing, 4)
                }
            }
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
        }
        .frame(height: 20)
    }

    private func progressWidth(in geo: GeometryProxy) -> CGFloat {
        guard displayDuration > 0 else { return 0 }
        return CGFloat(displayTime / displayDuration) * geo.size.width
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

// MARK: - Album Art


// MARK: - Volume Slider with Hover Effect

struct HoverVolumeSlider: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc
    @State private var isHovering = false

    private var volumeIcon: String {
        if playerVM.volume == 0 { return "speaker.slash.fill" }
        if playerVM.volume < 0.33 { return "speaker.wave.1.fill" }
        if playerVM.volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: volumeIcon)
                .font(.system(size: 11))
                .foregroundColor(tc.textTertiary)
                .frame(width: 14)
            Slider(value: Binding(
                get: { playerVM.volume },
                set: { playerVM.setVolume($0) }
            ), in: 0...1)
            .tint(tc.accent)
            .opacity(isHovering ? 1 : 0.6)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .frame(width: 60)
        }
        .onHover { isHovering = $0 }
    }
}

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
            .fill(Color(hex: "EEEEEE"))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.35))
                    .foregroundColor(Color(hex: "CCCCCC"))
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
