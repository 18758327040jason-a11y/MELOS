import SwiftUI

struct PlaylistSidebarView: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("歌单")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#5F6368"))
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            if playlistVM.playlists.isEmpty {
                EmptyPlaylistHint()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(playlistVM.playlists) { playlist in
                            PlaylistRowView(playlist: playlist)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            Spacer()
        }
        .background(Color(hex: "#F8F9FA"))
    }
}

// MARK: - Empty Hint

struct EmptyPlaylistHint: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "#DADCE0"))
            Text("还没有歌单")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#9AA0A6"))
            Text("点击右上角添加 QQ音乐 或\n网易云音乐歌单")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#9AA0A6"))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Button(action: { playlistVM.showAddSheet = true }) {
                Text("添加歌单")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#1A73E8"))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Playlist Row

struct PlaylistRowView: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    let playlist: Playlist

    var isSelected: Bool {
        playlistVM.selectedPlaylist?.id == playlist.id
    }

    var body: some View {
        HStack(spacing: 10) {
            // Platform icon
            Image(systemName: playlist.platform.iconName)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: playlist.platform.brandColor))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(playlist.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Color(hex: "#1A73E8") : Color(hex: "#202124"))
                    .lineLimit(1)

                Text("\(playlist.songCount) 首")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#9AA0A6"))
            }

            Spacer()

            // Playing indicator
            if playerVM.currentSong != nil && playerVM.currentPlaylist.firstIndex(of: playerVM.currentSong!) != nil {
                Circle()
                    .fill(Color(hex: "#1A73E8"))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color(hex: "#E8F0FE") : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            playlistVM.selectPlaylist(playlist)
        }
        .contextMenu {
            Button("刷新歌单") {
                Task {
                    await playlistVM.refreshPlaylist(playlist)
                }
            }
            Divider()
            Button("删除歌单", role: .destructive) {
                Task {
                    await playlistVM.deletePlaylist(playlist)
                }
            }
        }
    }
}
