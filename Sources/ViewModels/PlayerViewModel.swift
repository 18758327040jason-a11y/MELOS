import SwiftUI
import Combine

enum PlayMode: String, CaseIterable {
    case sequential = "顺序播放"
    case shuffle = "随机播放"
    case loopOne = "单曲循环"
    case loopAll = "列表循环"

    var icon: String {
        switch self {
        case .sequential: return "arrow.forward"
        case .shuffle: return "shuffle"
        case .loopOne: return "repeat.1"
        case .loopAll: return "repeat"
        }
    }
}

enum PlaybackState: Equatable {
    case idle           // 无选中歌曲
    case ready          // 歌曲已选中，等待点击播放
    case playing        // 正在播放
    case failed         // 播放失败

    static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.ready, .ready), (.playing, .playing), (.failed, .failed):
            return true
        default: return false
        }
    }
}

@MainActor
class PlayerViewModel: ObservableObject {
    static let shared = PlayerViewModel()

    // 列表中选中的歌曲（高亮用，不触发播放）
    @Published var selectedSong: Song?
    // 正在播放的歌曲
    @Published var currentSong: Song?
    @Published var playMode: PlayMode = .sequential
    @Published var currentPlaylist: [Song] = []
    @Published var currentIndex: Int = -1
    @Published var playbackState: PlaybackState = .idle
    @Published var playbackError: String?

    let audioService = AudioPlayerService.shared

    var isPlaying: Bool { audioService.isPlaying }
    var currentTime: Double { audioService.currentTime }
    var duration: Double { audioService.duration }
    var volume: Double { audioService.volume }
    var isLoading: Bool { audioService.isLoading }

    private init() {}

    // MARK: - List interaction: select song (not play)

    func selectSong(_ song: Song, in playlist: [Song]) {
        selectedSong = song
        currentSong = song  // so row highlights immediately
        currentPlaylist = playlist
        if let idx = playlist.firstIndex(of: song) {
            currentIndex = idx
        }
        // Only select — do NOT auto-play. Button state becomes "ready".
        playbackState = .ready
        playbackError = nil
    }

    // MARK: - Playback: triggered by button

    func startPlayback() {
        guard let song = selectedSong ?? currentSong else { return }
        playbackError = nil
        currentSong = song
        audioService.startPlayback(song: song) { [weak self] success, errorMessage in
            Task { @MainActor in
                if success {
                    self?.playbackState = .playing
                } else {
                    self?.playbackError = errorMessage ?? "无法播放该歌曲"
                    self?.playbackState = .failed
                }
            }
        }
    }

    func togglePlayPause() {
        if playbackState == .playing {
            audioService.pause()
            playbackState = .ready
        } else if playbackState == .ready {
            startPlayback()
        }
    }

    func playAt(index: Int) {
        guard index >= 0, index < currentPlaylist.count else { return }
        currentIndex = index
        let song = currentPlaylist[index]
        selectedSong = song
        currentSong = song
        audioService.startPlayback(song: song) { [weak self] success, errorMessage in
            Task { @MainActor in
                if success {
                    self?.playbackState = .playing
                } else {
                    self?.playbackError = errorMessage ?? "无法播放该歌曲"
                    self?.playbackState = .failed
                }
            }
        }
    }

    func playNext() {
        guard !currentPlaylist.isEmpty else { return }
        let nextIndex: Int
        switch playMode {
        case .sequential:
            nextIndex = currentIndex + 1
            if nextIndex >= currentPlaylist.count { stop(); return }
        case .shuffle:
            nextIndex = Int.random(in: 0..<currentPlaylist.count)
        case .loopOne:
            nextIndex = currentIndex
            audioService.seek(to: 0)
            audioService.resume()
            return
        case .loopAll:
            nextIndex = (currentIndex + 1) % currentPlaylist.count
        }
        playAt(index: nextIndex)
    }

    func playPrevious() {
        guard !currentPlaylist.isEmpty else { return }
        let prevIndex: Int
        switch playMode {
        case .sequential, .loopAll:
            prevIndex = currentIndex - 1 < 0 ? currentPlaylist.count - 1 : currentIndex - 1
        case .shuffle:
            prevIndex = Int.random(in: 0..<currentPlaylist.count)
        case .loopOne:
            prevIndex = currentIndex
        }
        playAt(index: prevIndex)
    }

    func stop() {
        selectedSong = nil
        currentSong = nil
        playbackState = .idle
        playbackError = nil
        audioService.stop()
    }

    func seek(to seconds: Double) {
        audioService.seek(to: seconds)
    }

    func setVolume(_ value: Double) {
        audioService.setVolume(value)
    }

    func cyclePlayMode() {
        let allCases = PlayMode.allCases
        if let idx = allCases.firstIndex(of: playMode) {
            playMode = allCases[(idx + 1) % allCases.count]
        }
    }

    func onSongEnded() {
        playNext()
    }

    func dismissError() {
        playbackError = nil
        audioService.cancelLoading()
        if playbackState == .failed {
            playbackState = selectedSong != nil ? .ready : .idle
        }
    }
}
