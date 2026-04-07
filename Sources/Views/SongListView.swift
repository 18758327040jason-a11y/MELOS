import SwiftUI

// MARK: - Song List View

struct SongListView: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        VStack(spacing: 0) {
            if let playlist = playlistVM.selectedPlaylist {
                // Header fixed at top (NOT inside ScrollView)
                PlaylistHeader(playlist: playlist)

                // Songs list — ScrollView fills remaining space
                if playlistVM.filteredSongs.isEmpty {
                    SongListEmptyState()
                } else {
                    ScrollViewReader { proxy in
                        GeometryReader { geo in
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    SongTableHeader()
                                    ForEach(Array(playlistVM.filteredSongs.enumerated()), id: \.element.id) { index, song in
                                        SongRow(song: song, index: index + 1)
                                            .id(song.id)
                                    }
                                }
                            }
                            .frame(height: geo.size.height - (playerVM.isMiniPlayer ? 48 : 88))
                            .onChange(of: playerVM.currentSong?.id) { _, newId in
                                if let id = newId {
                                    withAnimation(Theme.Anim.medium) {
                                        proxy.scrollTo(id, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                EmptyStateView()
            }
        }
        .background(tc.bgPrimary)
    }
}

// MARK: - Playlist Header

struct PlaylistHeader: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @Environment(\.themeColors) var tc
    let playlist: Playlist

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: Theme.Spacing.lg) {
                // Album art (small, left)
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(tc.accentLight.opacity(0.2))
                        .frame(width: 64, height: 64)

                    Image(systemName: "music.note.list")
                        .font(.system(size: 24))
                        .foregroundColor(tc.accent.opacity(0.5))
                }

                // Info (fill remaining space)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(Color(hex: playlist.platform.brandColor))
                            .frame(width: 7, height: 7)
                        Text(playlist.platform.rawValue)
                            .font(.system(size: Theme.FontSize.small))
                            .foregroundColor(tc.textSecondary)
                    }

                    Text(playlist.name)
                        .font(.system(size: Theme.FontSize.heading, weight: .bold))
                        .foregroundColor(tc.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: Theme.Spacing.sm) {
                        Text("\(playlist.songCount) 首歌曲")
                            .font(.system(size: Theme.FontSize.small))
                            .foregroundColor(tc.textSecondary)

                        if let lastSync = playlist.lastSyncTime {
                            Text("·")
                                .foregroundColor(tc.textTertiary)
                            Text("同步于 \(lastSync.formatted(.relative(presentation: .named)))")
                                .font(.system(size: Theme.FontSize.small))
                                .foregroundColor(tc.textTertiary)
                        }
                    }
                }

                Spacer()

                // Buttons (right side)
                HStack(spacing: Theme.Spacing.sm) {
                    if !playlist.songs.isEmpty {
                        Button(action: {
                            PlayerViewModel.shared.selectSong(playlist.songs[0], in: playlist.songs)
                            PlayerViewModel.shared.startPlayback()
                        }) {
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 12))
                                Text("播放全部")
                                    .font(.system(size: Theme.FontSize.body, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(Capsule().fill(tc.accent))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: {
                        Task { await playlistVM.refreshPlaylist(playlist) }
                    }) {
                        HStack(spacing: Theme.Spacing.xs) {
                            if playlistVM.isLoading {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                            }
                            Text("同步")
                                .font(.system(size: Theme.FontSize.body, weight: .medium))
                        }
                        .foregroundColor(tc.accent)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(Capsule().stroke(tc.accent.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
        }
    }

}

// MARK: - Table Header

struct SongTableHeader: View {
    @Environment(\.themeColors) var tc

    var body: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 36, alignment: .leading)
            Text("歌曲")
            Spacer()
            Text("专辑")
                .frame(width: 140, alignment: .leading)
            Text("时长")
                .frame(width: 60, alignment: .trailing)
        }
        .font(.system(size: Theme.FontSize.small, weight: .medium))
        .foregroundColor(tc.textTertiary)
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
    }
}

// MARK: - Song Row

struct SongRow: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @Environment(\.themeColors) var tc
    let song: Song
    let index: Int

    @State private var isHovered = false

    var isCurrentSong: Bool {
        playerVM.currentSong?.id == song.id
    }

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Text("\(index)")
                    .font(.system(size: Theme.FontSize.body, design: .monospaced))
                    .foregroundColor(tc.textTertiary)
            }
            .frame(width: 36, alignment: .leading)

            AlbumArtView(url: song.coverUrl, size: 40)
                .padding(.trailing, Theme.Spacing.md)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(song.title)
                        .font(.system(size: Theme.FontSize.body, weight: isCurrentSong ? .semibold : .medium))
                        .foregroundColor(isCurrentSong ? tc.accent : tc.textPrimary)
                        .lineLimit(1)
                    if DownloadService.shared.isDownloaded(song.id) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "34C759"))
                    }
                }
                Text(song.artist)
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundColor(isCurrentSong ? tc.accent : tc.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(song.album ?? "—")
                .font(.system(size: Theme.FontSize.caption))
                .foregroundColor(tc.textSecondary)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text(song.formattedDuration)
                .font(.system(size: Theme.FontSize.caption, design: .monospaced))
                .foregroundColor(tc.textTertiary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(isCurrentSong ? tc.accentLight.opacity(0.15) : (isHovered ? tc.hover : Color.clear))
                .padding(.horizontal, Theme.Spacing.md)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let playlist = playlistVM.selectedPlaylist {
                playerVM.selectSong(song, in: playlist.songs)
            }
        }
        .onHover { isHovered = $0 }
    }
}

// MARK: - Empty States

struct SongListEmptyState: View {
    @Environment(\.themeColors) var tc

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundColor(tc.textTertiary)
            Text("歌单为空")
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(tc.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
