import SwiftUI

struct PlayerBarView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            .overlay(
                Rectangle()
                    .fill(Color(hex: "#F8F9FA").opacity(0.95))
            )
            .overlay(
                VStack(spacing: 0) {
                    // Progress bar
                    ProgressBar()

                    // Controls
                    HStack(spacing: 0) {
                        // Left: song info
                        SongInfoView()
                            .frame(width: 240)

                        Spacer()

                        // Center: play controls
                        PlayControlsView()

                        Spacer()

                        // Right: volume
                        VolumeView()
                            .frame(width: 140)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            )
    }
}

// MARK: - Song Info

struct SongInfoView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Album art
            Group {
                if let coverUrl = playerVM.currentSong?.coverUrl,
                   let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: "#DADCE0"))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(Color(hex: "#5F6368"))
                            )
                    }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "#DADCE0"))
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(Color(hex: "#5F6368"))
                        )
                }
            }
            .frame(width: 48, height: 48)
            .cornerRadius(6)

            // Title & artist
            VStack(alignment: .leading, spacing: 2) {
                if let song = playerVM.currentSong {
                    Text(song.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#202124"))
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#5F6368"))
                        .lineLimit(1)
                } else {
                    Text("未播放")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#9AA0A6"))
                    Text("")
                        .font(.system(size: 11))
                }
            }

            Spacer()
        }
    }
}

// MARK: - Play Controls

struct PlayControlsView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Previous
            Button(action: { playerVM.playPrevious() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#5F6368"))
            }
            .buttonStyle(.plain)
            .disabled(playerVM.currentSong == nil)

            // Play/Pause
            Button(action: { playerVM.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#1A73E8"))
                        .frame(width: 36, height: 36)

                    if playerVM.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                            .tint(.white)
                    } else {
                        Image(systemName: playerVM.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: playerVM.isPlaying ? 0 : 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(playerVM.currentSong == nil)

            // Next
            Button(action: { playerVM.playNext() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#5F6368"))
            }
            .buttonStyle(.plain)
            .disabled(playerVM.currentSong == nil)

            // Play mode
            Button(action: { playerVM.cyclePlayMode() }) {
                Image(systemName: playerVM.playMode.icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#5F6368"))
            }
            .buttonStyle(.plain)
            .padding(.leading, 4)
        }
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
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#DADCE0"))
                    .frame(height: 4)

                // Progress
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#1A73E8"))
                    .frame(width: progressWidth(in: geo), height: 4)

                // Knob (show on hover/drag)
                if isDragging || isHovering {
                    Circle()
                        .fill(Color(hex: "#1A73E8"))
                        .frame(width: 12, height: 12)
                        .offset(x: progressWidth(in: geo) - 6)
                        .animation(.easeOut(duration: 0.1), value: isDragging)
                }
            }
            .frame(height: 20)
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
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func progressWidth(in geo: GeometryProxy) -> CGFloat {
        guard playerVM.duration > 0 else { return 0 }
        let ratio = displayTime / displayDuration
        return CGFloat(ratio) * geo.size.width
    }
}

// MARK: - Volume

struct VolumeView: View {
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: volumeIcon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#5F6368"))

            Slider(value: Binding(
                get: { playerVM.volume },
                set: { playerVM.setVolume($0) }
            ), in: 0...1)
            .tint(Color(hex: "#1A73E8"))

            Text("\(Int(playerVM.volume * 100))")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#5F6368"))
                .frame(width: 28, alignment: .trailing)
        }
    }

    var volumeIcon: String {
        if playerVM.volume == 0 { return "speaker.slash.fill" }
        if playerVM.volume < 0.33 { return "speaker.wave.1.fill" }
        if playerVM.volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
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
