import SwiftUI

struct SongListView: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @EnvironmentObject var playerVM: PlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let playlist = playlistVM.selectedPlaylist {
                // Playlist header
                PlaylistHeaderView(playlist: playlist)

                Divider()

                // Song list
                if playlistVM.filteredSongs.isEmpty {
                    EmptySongListView()
                } else {
                    SongTableView(songs: playlistVM.filteredSongs)
                }
            } else {
                NoPlaylistSelectedView()
            }
        }
        .background(Color(hex: "#FFFFFF"))
    }
}

// MARK: - Playlist Header

struct PlaylistHeaderView: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    let playlist: Playlist

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Cover
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#E8F0FE"))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "#1A73E8"))
                    )

                VStack(alignment: .leading, spacing: 8) {
                    // Platform badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: playlist.platform.brandColor))
                            .frame(width: 8, height: 8)
                        Text(playlist.platform.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "#5F6368"))
                    }

                    Text(playlist.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#202124"))
                        .lineLimit(2)

                    Text("\(playlist.songCount) 首歌曲")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#5F6368"))

                    if let lastSync = playlist.lastSyncTime {
                        Text("上次同步: \(lastSync.formatted(.relative(presentation: .named)))")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#9AA0A6"))
                    }

                    HStack(spacing: 10) {
                        Button(action: {
                            Task {
                                await playlistVM.refreshPlaylist(playlist)
                            }
                        }) {
                            HStack(spacing: 4) {
                                if playlistVM.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 11))
                                }
                                Text("同步")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "#1A73E8"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(hex: "#E8F0FE"))
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(20)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#9AA0A6"))
                TextField("在歌单内搜索...", text: $playlistVM.searchText)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(hex: "#F1F3F4"))
            .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Song Table

struct SongTableView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    let songs: [Song]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Table header
                HStack(spacing: 0) {
                    Text("#")
                        .frame(width: 40, alignment: .leading)
                    Text("标题")
                    Spacer()
                    Text("艺术家")
                        .frame(width: 140, alignment: .leading)
                    Text("时长")
                        .frame(width: 60, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(hex: "#9AA0A6"))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(hex: "#FAFAFA"))

                Divider()

                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    SongRowView(song: song, index: index + 1)
                    if index < songs.count - 1 {
                        Divider()
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
}

// MARK: - Song Row

struct SongRowView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var playlistVM: PlaylistViewModel
    let song: Song
    let index: Int

    var isCurrentSong: Bool {
        playerVM.currentSong?.id == song.id
    }

    var body: some View {
        HStack(spacing: 0) {
            // Index or playing indicator
            ZStack {
                Text("\(index)")
                    .font(.system(size: 13))
                    .foregroundColor(isCurrentSong ? Color(hex: "#1A73E8") : Color(hex: "#9AA0A6"))
            }
            .frame(width: 40, alignment: .leading)

            // Title + artist
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.system(size: 13, weight: isCurrentSong ? .semibold : .medium))
                    .foregroundColor(isCurrentSong ? Color(hex: "#1A73E8") : Color(hex: "#202124"))
                    .lineLimit(1)
                Text(song.artist)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#9AA0A6"))
                    .lineLimit(1)
            }

            Spacer()

            // Artist (if truncated from title)
            Text(song.artist)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#5F6368"))
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            // Duration
            Text(song.formattedDuration)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#9AA0A6"))
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(isCurrentSong ? Color(hex: "#E8F0FE").opacity(0.4) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if let playlist = playlistVM.selectedPlaylist {
                playerVM.play(song: song, in: playlist.songs)
            }
        }
        .onHover { hovering in
            // Simple hover effect via background
        }
    }
}

// MARK: - Empty States

struct EmptySongListView: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#DADCE0"))
            Text(playlistVM.searchText.isEmpty ? "歌单为空" : "未找到相关歌曲")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#9AA0A6"))
            if !playlistVM.searchText.isEmpty {
                Text("试试其他关键词")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#DADCE0"))
            }
            Spacer()
        }
    }
}

struct NoPlaylistSelectedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "hand.point.left")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#DADCE0"))
            Text("从左侧选择一个歌单")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#9AA0A6"))
            Spacer()
        }
    }
}
