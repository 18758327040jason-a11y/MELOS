import SwiftUI

// MARK: - Right Panel (Lyrics / Queue / History)

struct RightPanelView: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(playerVM.rightPanel.rawValue)
                    .font(.system(size: Theme.FontSize.heading, weight: .semibold))
                    .foregroundColor(tc.textPrimary)
                Spacer()
                Button(action: { playerVM.rightPanel = .none }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(tc.textTertiary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(tc.bgSecondary)

            Divider()
                .background(tc.divider)

            // Content
            switch playerVM.rightPanel {
            case .lyrics:
                LyricsContent()
            case .queue:
                QueueContent()
            case .history:
                HistoryContent()
            case .none:
                EmptyView()
            }
        }
        .frame(width: Theme.Sizes.rightPanelWidth)
        .background(tc.bgPrimary)
    }
}

// MARK: - Lyrics Content

struct LyricsContent: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc
    @State private var lyrics: [String] = []
    @State private var currentLineIndex: Int = 0
    @State private var isLoading = false
    @State private var hasLyrics = false

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.8)
                Spacer()
            } else if hasLyrics {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            ForEach(Array(lyrics.enumerated()), id: \.offset) { index, line in
                                Text(line.isEmpty ? "♪" : line)
                                    .font(.system(size: index == currentLineIndex ? Theme.FontSize.body : Theme.FontSize.caption, weight: index == currentLineIndex ? .semibold : .regular))
                                    .foregroundColor(index == currentLineIndex ? tc.accent : tc.textTertiary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                                    .padding(.horizontal, Theme.Spacing.lg)
                                    .padding(.vertical, Theme.Spacing.xs)
                                    .background(index == currentLineIndex ? tc.accentLight.opacity(0.5) : Color.clear)
                                    .cornerRadius(Theme.Radius.xs)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.lg)
                    }
                    .onChange(of: currentLineIndex) { _, newIndex in
                        withAnimation(Theme.Anim.medium) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            } else {
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "quote.bubble")
                        .font(.system(size: 32))
                        .foregroundColor(tc.textTertiary)
                    Text("暂无歌词")
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(tc.textSecondary)
                }
                Spacer()
            }
        }
        .background(tc.bgPrimary)
        .onAppear { fetchLyrics() }
        .onChange(of: playerVM.currentSong?.id) { _, _ in fetchLyrics() }
        .onChange(of: playerVM.currentTime) { _, time in updateCurrentLine(time) }
    }

    private func fetchLyrics() {
        guard let song = playerVM.currentSong else {
            lyrics = []; hasLyrics = false; return
        }
        // Only NetEase has free lyrics API
        guard song.platform == .netEase else {
            lyrics = ["[此平台暂不支持歌词]", "——"]
            hasLyrics = true
            currentLineIndex = 0
            return
        }
        // Extract numeric ID from song.id (e.g. "netease_12345" → "12345")
        let numericId = song.id.replacingOccurrences(of: "netease_", with: "")
        guard !numericId.isEmpty else {
            lyrics = ["[无法解析歌曲ID]"]
            hasLyrics = true; return
        }

        isLoading = true
        hasLyrics = false
        Task {
            do {
                var request = URLRequest(url: URL(string: "https://music.163.com/api/song/lyric?id=\(numericId)&type=1")!)
                request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let lrc = json["lrc"] as? [String: Any],
                   let text = lrc["lyric"] as? String {
                    let lines = text.components(separatedBy: "\n")
                        .map { line -> String in
                            // Parse [mm:ss.xx]timestamp[/mm:ss.xx]text → text
                            let pattern = "\\[\\d{2}:\\d{2}\\.\\d{2,}\\]"
                            return line.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
                                .trimmingCharacters(in: .whitespaces)
                        }
                        .filter { !$0.isEmpty }
                    await MainActor.run {
                        self.lyrics = lines
                        self.hasLyrics = !lines.isEmpty
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.lyrics = ["[获取歌词失败]"]
                        self.hasLyrics = true
                        self.isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.lyrics = ["[网络错误]"]
                    self.hasLyrics = true
                    self.isLoading = false
                }
            }
        }
    }

    private func updateCurrentLine(_ time: Double) {
        // Simple heuristics: each line ~3-4 seconds
        // NetEase lyrics timestamps not parsed here — just use time-based
        let estimatedIndex = min(Int(time / 3.5), lyrics.count - 1)
        if estimatedIndex != currentLineIndex && estimatedIndex >= 0 {
            currentLineIndex = estimatedIndex
        }
    }
}

// MARK: - Queue Content

struct QueueContent: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc

    var body: some View {
        if playerVM.currentPlaylist.isEmpty {
            VStack(spacing: Theme.Spacing.md) {
                Spacer()
                Image(systemName: "list.bullet")
                    .font(.system(size: 32))
                    .foregroundColor(tc.textTertiary)
                Text("播放列表为空")
                    .font(.system(size: Theme.FontSize.body))
                    .foregroundColor(tc.textSecondary)
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(playerVM.currentPlaylist.enumerated()), id: \.element.id) { index, song in
                        HStack(spacing: Theme.Spacing.md) {
                            ZStack {
                                Text("\(index + 1)")
                                    .font(.system(size: Theme.FontSize.small, design: .monospaced))
                                    .foregroundColor(
                                        index == playerVM.currentIndex
                                            ? tc.accent
                                            : tc.textTertiary
                                    )
                            }
                            .frame(width: 28, alignment: .leading)

                            AlbumArtView(url: song.coverUrl, size: 36)
                                .cornerRadius(Theme.Radius.xs)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(song.title)
                                    .font(.system(size: Theme.FontSize.body, weight: index == playerVM.currentIndex ? .semibold : .medium))
                                    .foregroundColor(index == playerVM.currentIndex ? tc.accent : tc.textPrimary)
                                    .lineLimit(1)
                                Text(song.artist)
                                    .font(.system(size: Theme.FontSize.small))
                                    .foregroundColor(tc.textTertiary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if index == playerVM.currentIndex && playerVM.playbackState == .playing {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(tc.accent)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            index == playerVM.currentIndex
                                ? tc.accentLight.opacity(0.5)
                                : Color.clear
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            playerVM.playAt(index: index)
                        }

                        Divider()
                            .background(tc.divider)
                            .padding(.leading, Theme.Spacing.lg + 28 + Theme.Spacing.md)
                    }
                }
            }
        }
    }
}

// MARK: - History Content

struct HistoryContent: View {
    @EnvironmentObject var playerVM: PlayerViewModel
    @Environment(\.themeColors) var tc
    @State private var historySongs: [Song] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                VStack { ProgressView().scaleEffect(0.8) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if historySongs.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Spacer()
                    Image(systemName: "clock")
                        .font(.system(size: 32))
                        .foregroundColor(tc.textTertiary)
                    Text("暂无播放历史")
                        .font(.system(size: Theme.FontSize.body))
                        .foregroundColor(tc.textSecondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(historySongs) { song in
                            HStack(spacing: Theme.Spacing.md) {
                                AlbumArtView(url: song.coverUrl, size: 36)
                                    .cornerRadius(Theme.Radius.xs)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(song.title)
                                        .font(.system(size: Theme.FontSize.body, weight: .medium))
                                        .foregroundColor(tc.textPrimary)
                                        .lineLimit(1)
                                    Text(song.artist)
                                        .font(.system(size: Theme.FontSize.small))
                                        .foregroundColor(tc.textTertiary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(song.formattedDuration)
                                    .font(.system(size: Theme.FontSize.small, design: .monospaced))
                                    .foregroundColor(tc.textTertiary)
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.vertical, Theme.Spacing.sm)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                playerVM.selectSong(song, in: historySongs)
                                playerVM.startPlayback()
                            }

                            Divider()
                                .background(tc.divider)
                                .padding(.leading, Theme.Spacing.lg + 36 + Theme.Spacing.md)
                        }
                    }
                }
            }
        }
        .task {
            historySongs = (try? await DatabaseService.shared.loadHistory()) ?? []
            isLoading = false
        }
    }
}
