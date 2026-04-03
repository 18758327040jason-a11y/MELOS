import SwiftUI

// MARK: - Mini Player

struct MiniPlayerView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Album art
            AlbumArtView(url: playerVM.currentSong?.coverUrl, size: 44)

            // Title + artist
            VStack(alignment: .leading, spacing: 2) {
                if let song = playerVM.currentSong {
                    Text(song.title)
                        .font(.system(size: Theme.FontSize.body, weight: .semibold))
                        .foregroundColor(tc.textPrimary)
                        .lineLimit(1)
                    Text(song.artist)
                        .font(.system(size: Theme.FontSize.small))
                        .foregroundColor(tc.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Prev / Play-Pause / Next
            HStack(spacing: Theme.Spacing.md) {
                Button(action: { playerVM.playPrevious() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(tc.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(playerVM.currentSong == nil)

                Button(action: { playerVM.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(tc.accent)
                            .frame(width: 36, height: 36)
                        if playerVM.isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .tint(.white)
                        } else {
                            Image(systemName: playerVM.playbackState == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                Button(action: { playerVM.playNext() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                        .foregroundColor(tc.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(playerVM.currentSong == nil)
            }

            // Expand button
            Button(action: { playerVM.isMiniPlayer = false }) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
                    .foregroundColor(tc.textTertiary)
            }
            .buttonStyle(.plain)
            .padding(.leading, Theme.Spacing.sm)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(height: Theme.Sizes.miniPlayerHeight)
        .background(tc.bgSecondary)
        .contentShape(Rectangle())
    }
}
