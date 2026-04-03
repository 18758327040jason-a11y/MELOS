import SwiftUI

// MARK: - Playlist Sidebar

struct PlaylistSidebarView: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text("歌单")
                    .font(.system(size: Theme.FontSize.caption, weight: .semibold))
                    .foregroundColor(tc.textTertiary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                Spacer()
                Text("\(playlistVM.playlists.count)")
                    .font(.system(size: Theme.FontSize.small, design: .monospaced))
                    .foregroundColor(tc.textTertiary)
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
        .background(tc.bgSecondary)
    }
}

// MARK: - Sidebar Empty Hint

struct SidebarEmptyHint: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 32))
                .foregroundColor(tc.textTertiary)
            Text("无歌单")
                .font(.system(size: Theme.FontSize.body))
                .foregroundColor(tc.textSecondary)
            Button(action: { playlistVM.showAddSheet = true }) {
                Text("添加")
                    .font(.system(size: Theme.FontSize.caption, weight: .medium))
                    .foregroundColor(tc.accent)
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
    @Environment(\.themeColors) var tc
    let playlist: Playlist

    @State private var isHovered = false

    var isSelected: Bool {
        playlistVM.selectedPlaylist?.id == playlist.id
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: playlist.platform.iconName)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: playlist.platform.brandColor))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.system(size: Theme.FontSize.body, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? tc.accent : tc.textPrimary)
                    .lineLimit(1)

                Text("\(playlist.songCount) 首")
                    .font(.system(size: Theme.FontSize.small))
                    .foregroundColor(tc.textTertiary)
            }

            Spacer()

            if playerVM.currentSong != nil && playerVM.currentPlaylist.contains(where: { $0.id == playerVM.currentSong?.id }) {
                Circle()
                    .fill(tc.accent)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .fill(
                    isSelected
                        ? tc.accentLight.opacity(0.2)
                        : (isHovered ? tc.hover : Color.clear)
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
