import SwiftUI

// MARK: - Playlist Sidebar

struct PlaylistSidebarView: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("歌单")
                    .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                    .foregroundColor(Theme.Palette.textTertiary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                Spacer()
                Text("\(playlistVM.playlists.count)")
                    .font(.system(size: Theme.FontSize.small, design: .monospaced))
                    .foregroundColor(Theme.Palette.textTertiary)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.md)

            if playlistVM.playlists.isEmpty {
                SidebarEmptyHint()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(playlistVM.playlists) { playlist in
                            PlaylistRow(playlist: playlist)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                }
            }

            Spacer()
        }
        .background(Theme.Palette.bgSecondary)
    }
}

// MARK: - Sidebar Empty Hint

struct SidebarEmptyHint: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 32))
                .foregroundColor(Theme.Palette.textTertiary)
            Text("无歌单")
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(Theme.Palette.textSecondary)
            Button(action: { playlistVM.showAddSheet = true }) {
                Text("添加")
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(Theme.Palette.accent)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Playlist Row

struct PlaylistRow: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    let playlist: Playlist

    @State private var isHovered = false

    var isSelected: Bool {
        playlistVM.selectedPlaylist?.id == playlist.id
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Platform icon
            Image(systemName: playlist.platform.iconName)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: playlist.platform.brandColor))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: Theme.FontSize.body, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.Palette.accent : Theme.Palette.textPrimary)
                    .lineLimit(1)

                Text("\(playlist.songCount) 首")
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundColor(Theme.Palette.textTertiary)
            }

            Spacer()

            // Playing indicator
            if playerVM.currentSong != nil && playerVM.currentPlaylist.contains(where: { $0.id == playerVM.currentSong?.id }) {
                Circle()
                    .fill(Theme.Palette.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(
                    isSelected
                        ? Theme.Palette.accentLight.opacity(0.2)
                        : (isHovered ? Theme.Palette.hover : Color.clear)
                )
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            playlistVM.selectPlaylist(playlist)
        }
        .contextMenu {
            Button("刷新") {
                Task { await playlistVM.refreshPlaylist(playlist) }
            }
            Divider()
            Button("删除", role: .destructive) {
                Task { await playlistVM.deletePlaylist(playlist) }
            }
        }
    }
}
