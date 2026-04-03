import SwiftUI

// MARK: - Song List View

struct SongListView: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        VStack(spacing: 0) {
            if let playlist = playlistVM.selectedPlaylist {
                PlaylistHeader(playlist: playlist)

                Divider()
                    .background(tc.divider)

                if playlistVM.filteredSongs.isEmpty {
                    SongListEmptyState()
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                SongTableHeader()
                                Divider()
                                    .padding(.horizontal, Theme.Spacing.xl)
                                ForEach(Array(playlistVM.filteredSongs.enumerated()), id: \.element.id) { index, song in
                                    SongRow(song: song, index: index + 1)
                                        .id(song.id)
                                }
                            }
                            .padding(.bottom, Theme.Spacing.md)
                        }
                        .onChange(of: playerVM.currentSong?.id) { _, newId in
                            if let id = newId {
                                withAnimation(Theme.Anim.medium) {
                                    proxy.scrollTo(id, anchor: .center)
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
        VStack(spacing: Theme.Spacing.lg) {
            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                // Large album art
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.lg)
                        .fill(tc.accentLight.opacity(0.2))
                        .frame(width: 130, height: 130)

                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundColor(tc.accent.opacity(0.5))
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(Color(hex: playlist.platform.brandColor))
                            .frame(width: 8, height: 8)
                        Text(playlist.platform.rawValue)
                            .font(.system(size: Theme.FontSize.caption, weight: .medium))
                            .foregroundColor(tc.textSecondary)
                    }

                    Text(playlist.name)
                        .font(.system(size: Theme.FontSize.title, weight: .bold))
                        .foregroundColor(tc.textPrimary)
                        .lineLimit(2)

                    Text("\(playlist.songCount) 首歌曲")
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(tc.textSecondary)

                    if let lastSync = playlist.lastSyncTime {
                        Text("同步于 \(lastSync.formatted(.relative(presentation: .named)))")
                            .font(.system(size: Theme.FontSize.small))
                            .foregroundColor(tc.textTertiary)
                    }

                    HStack(spacing: Theme.Spacing.sm) {
                        if !playlist.songs.isEmpty {
                            Button(action: {
                                playerVM.selectSong(playlist.songs[0], in: playlist.songs)
                                playerVM.startPlayback()
                            }) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 13))
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
                                        .font(.system(size: 13))
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

                Spacer()
            }
            .padding(Theme.Spacing.xl)

            // Search bar
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: Theme.FontSize.caption))
                    .foregroundColor(tc.textTertiary)
                TextField("搜索歌曲、艺术家...", text: $playlistVM.searchText)
                    .font(.system(size: Theme.FontSize.body))
                    .textFieldStyle(.plain)
                if !playlistVM.searchText.isEmpty {
                    Button(action: { playlistVM.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: Theme.FontSize.body))
                            .foregroundColor(tc.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(tc.bgTertiary))
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.md)
        }
    }

    private var playerVM: PlayerViewModel { .shared }
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
                Text(song.title)
                    .font(.system(size: Theme.FontSize.body, weight: isCurrentSong ? .semibold : .medium))
                    .foregroundColor(isCurrentSong ? tc.accent : tc.textPrimary)
                    .lineLimit(1)
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
