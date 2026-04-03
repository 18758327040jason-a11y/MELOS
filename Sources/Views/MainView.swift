import SwiftUI

struct MainView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var playlistVM: PlaylistViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            TopToolbar()

            Divider()

            // Content
            HStack(spacing: 0) {
                // Left sidebar: playlist list
                PlaylistSidebarView()
                    .frame(width: 240)

                Divider()

                // Right: song list
                SongListView()
            }

            Divider()

            // Bottom: playback bar
            PlayerBarView()
                .frame(height: 80)
        }
        .frame(minWidth: 700, minHeight: 480)
        .background(Color(hex: "#FFFFFF"))
        .sheet(isPresented: $playlistVM.showAddSheet) {
            AddPlatformSheet()
        }
        .task {
            await playlistVM.loadPlaylists()
        }
    }
}

// MARK: - Top Toolbar

struct TopToolbar: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel

    var body: some View {
        HStack(spacing: 16) {
            Text("MusicPlayer")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#202124"))

            Spacer()

            Button(action: { playlistVM.showAddSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                    Text("添加歌单")
                        .font(.system(size: 13))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(hex: "#1A73E8"))
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(hex: "#F8F9FA"))
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environmentObject(PlayerViewModel.shared)
        .environmentObject(PlaylistViewModel.shared)
}
