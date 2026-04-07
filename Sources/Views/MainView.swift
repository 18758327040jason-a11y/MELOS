import SwiftUI

struct MainView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @Environment(\.themeColors) var tc

    @State private var sidebarWidth: CGFloat = 200

    var body: some View {
        HStack(spacing: 0) {
            // Left: content + player bar (stacked, player bar overlays bottom)
            ZStack(alignment: .bottom) {
                // Content layer
                VStack(spacing: 0) {
                    TitleBar()

                    // Content area — full width, solid background
                    HStack(spacing: 0) {
                        // Sidebar
                        PlaylistSidebarView()
                            .frame(width: effectiveSidebarWidth)

                        // Draggable divider
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 6)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newWidth = value.startLocation.x + value.translation.width
                                        sidebarWidth = min(max(newWidth, 120), 360)
                                    }
                            )

                        // Main song list area
                        if playlistVM.selectedPlaylist != nil {
                            SongListView()
                        } else {
                            EmptyStateView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(tc.bgSecondary)

                // Player bar — solid bg covers any gap at the bottom
                PlayerBarView()
                    .frame(height: playerBarHeight)
            }
            .frame(maxWidth: .infinity)

            // Right panel (slides in from right)
            if playerVM.rightPanel != .none {
                RightPanelView()
                    .transition(.move(edge: .trailing))
                    .animation(Theme.Anim.fast, value: playerVM.rightPanel)
            }
        }
        .frame(minWidth: 800, minHeight: 540)
        .background(tc.bgPrimary)
        .sheet(isPresented: $playlistVM.showAddSheet) {
            AddPlatformSheet().themed()
        }
        .task {
            await playlistVM.loadPlaylists()
        }
    }

    private var effectiveSidebarWidth: CGFloat {
        playerVM.rightPanel == .none ? sidebarWidth : 200
    }

    private var playerBarHeight: CGFloat {
        playerVM.isMiniPlayer ? Theme.Sizes.miniPlayerHeight : 88
    }
}

// MARK: - Title Bar

struct TitleBar: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "music.note.list")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(tc.accent)

            Text("Melos")
                .font(.system(size: Theme.FontSize.body, weight: .semibold))
                .foregroundColor(tc.textPrimary)

            Spacer()

            // Search field (center)
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(tc.textTertiary)
                TextField("搜索歌曲、艺术家...", text: $playlistVM.searchText)
                    .font(.system(size: Theme.FontSize.body))
                    .textFieldStyle(.plain)
                    .frame(width: 200)
                if !playlistVM.searchText.isEmpty {
                    Button(action: { playlistVM.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(tc.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md).fill(tc.bgTertiary))

            Spacer()

            Button(action: cycleColorScheme) {
                Image(systemName: colorSchemeIcon)
                    .font(.system(size: 12))
                    .foregroundColor(tc.textTertiary)
            }
            .buttonStyle(.plain)
            .help(colorSchemeHelp)

            Button(action: { playlistVM.showAddSheet = true }) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("添加歌单")
                        .font(.system(size: Theme.FontSize.caption))
                }
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Capsule().fill(tc.accent))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(tc.bgSecondary)
    }

    private var colorSchemeIcon: String {
        switch playerVM.darkModeOverride {
        case .some(true): return "moon.fill"
        case .some(false): return "sun.max.fill"
        case nil: return "circle.lefthalf.filled"
        }
    }

    private var colorSchemeHelp: String {
        switch playerVM.darkModeOverride {
        case .some(true): return "当前：深色模式，点击切换跟随系统"
        case .some(false): return "当前：浅色模式，点击切换跟随系统"
        case nil: return "当前：跟随系统，点击切换深色模式"
        }
    }

    private func cycleColorScheme() {
        switch playerVM.darkModeOverride {
        case nil: playerVM.darkModeOverride = true
        case true: playerVM.darkModeOverride = false
        case false: playerVM.darkModeOverride = nil
        }
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    @EnvironmentObject var playlistVM: PlaylistViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(tc.accentLight.opacity(0.3))
                    .frame(width: 120, height: 120)

                Image(systemName: "music.note.list")
                    .font(.system(size: 44))
                    .foregroundColor(tc.accent.opacity(0.6))
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("开始听音乐")
                    .font(.system(size: Theme.FontSize.title, weight: .semibold))
                    .foregroundColor(tc.textPrimary)

                Text("添加 QQ 音乐或网易云音乐歌单\n从左侧歌单列表选择要播放的歌曲")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(tc.textSecondary)
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
                .background(Capsule().fill(tc.accent))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(tc.bgPrimary)
    }
}

#Preview {
    MainView()
        .environmentObject(PlayerViewModel.shared)
        .environmentObject(PlaylistViewModel.shared)
        .themed()
}
