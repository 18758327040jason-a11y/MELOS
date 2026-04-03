import SwiftUI

struct MainView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var playlistVM: PlaylistViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            TitleBar()

            Divider()

            // Content
            HStack(spacing: 0) {
                // Sidebar
                PlaylistSidebarView()
                    .frame(width: Theme.Sizes.sidebarWidth)

                Divider()

                // Main area
                if let _ = playlistVM.selectedPlaylist {
                    SongListView()
                } else {
                    EmptyStateView()
                }
            }

            Divider()

            // Player bar
            PlayerBarView()
                .frame(height: Theme.Sizes.playerBarHeight)
        }
        .frame(minWidth: 800, minHeight: 540)
        .background(Theme.Palette.bgPrimary)
        .sheet(isPresented: $playlistVM.showAddSheet) {
            AddPlatformSheet()
        }
        .task {
            await playlistVM.loadPlaylists()
        }
    }
}

// MARK: - Title Bar

struct TitleBar: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // App icon
            Image(systemName: "music.note.list")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.Palette.accent)

            Text("MusicPlayer")
                .font(.system(size: Theme.FontSize.heading, weight: .semibold))
                .foregroundColor(Theme.Palette.textPrimary)

            Spacer()

            // Add playlist button
            Button(action: { playlistVM.showAddSheet = true }) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("添加歌单")
                        .font(.system(size: Theme.FontSize.body))
                }
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    Capsule()
                        .fill(Theme.Palette.accent)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.vertical, Theme.Spacing.lg)
        .background(Theme.Palette.bgSecondary)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            // Large icon
            ZStack {
                Circle()
                    .fill(Theme.Palette.accentLight.opacity(0.3))
                    .frame(width: 120, height: 120)

                Image(systemName: "music.note.list")
                    .font(.system(size: 44))
                    .foregroundColor(Theme.Palette.accent.opacity(0.6))
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("开始听音乐")
                    .font(.system(size: Theme.FontSize.title, weight: .semibold))
                    .foregroundColor(Theme.Palette.textPrimary)

                Text("添加 QQ 音乐或网易云音乐歌单\n从左侧歌单列表选择要播放的歌曲")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button(action: { playlistVM.showAddSheet = true }) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 15))
                    Text("添加歌单")
                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    Capsule()
                        .fill(Theme.Palette.accent)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Palette.bgPrimary)
    }
}

#Preview {
    MainView()
        .environmentObject(PlayerViewModel.shared)
        .environmentObject(PlaylistViewModel.shared)
}
