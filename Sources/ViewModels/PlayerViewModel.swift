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
    case idle
    case ready
    case playing
    case failed

    static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.ready, .ready), (.playing, .playing), (.failed, .failed):
            return true
        default: return false
        }
    }
}

enum RightPanelType: String, CaseIterable {
    case lyrics = "歌词"
    case queue = "播放列表"
    case none = ""

    var icon: String {
        switch self {
        case .lyrics: return "quote.bubble"
        case .queue: return "list.bullet"
        case .none: return ""
        }
    }
}

@MainActor
class PlayerViewModel: ObservableObject {
    static let shared = PlayerViewModel()

    // Playback
    @Published var selectedSong: Song?
    @Published var currentSong: Song?
    @Published var playMode: PlayMode = .sequential
    @Published var currentPlaylist: [Song] = []
    @Published var currentIndex: Int = -1
    @Published var playbackState: PlaybackState = .idle
    @Published var playbackError: String?
    // Published wrapper so SwiftUI tracks currentTime changes
    @Published var currentTime: Double = 0

    // UI state
    @Published var rightPanel: RightPanelType = .none
    @Published var isMiniPlayer: Bool = false

    // Dark mode: nil = follow system, true = dark, false = light
    @AppStorage("darkModeOverride") var darkModeOverride: Bool?

    let audioService = AudioPlayerService.shared
    private var timeCancellable: AnyCancellable?

    var isPlaying: Bool { audioService.isPlaying }
    var duration: Double { audioService.duration }
    var volume: Double { audioService.volume }
    var isLoading: Bool { audioService.isLoading }

    var effectiveColorScheme: ColorScheme? {
        switch darkModeOverride {
        case .some(true): return .dark
        case .some(false): return .light
        case nil: return nil
        }
    }

    private init() {
        timeCancellable = audioService.$currentTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] t in self?.currentTime = t }
    }

    // MARK: - Select (highlight only)

    func selectSong(_ song: Song, in playlist: [Song]) {
        selectedSong = song
        currentSong = song
        currentPlaylist = playlist
        if let idx = playlist.firstIndex(of: song) { currentIndex = idx }
        playbackState = .ready
        playbackError = nil
    }

    // MARK: - Playback

    func startPlayback() {
        guard let song = selectedSong ?? currentSong else { return }
        playbackError = nil
        currentSong = song
        audioService.onSongFinished = { [weak self] in
            Task { @MainActor in
                self?.onSongEnded()
            }
        }
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
        audioService.onSongFinished = { [weak self] in
            Task { @MainActor in
                self?.onSongEnded()
            }
        }
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
            seek(to: 0); audioService.resume(); return
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

    func seek(to seconds: Double) { audioService.seek(to: seconds) }
    func setVolume(_ value: Double) { audioService.setVolume(value) }

    func cyclePlayMode() {
        let allCases = PlayMode.allCases
        if let idx = allCases.firstIndex(of: playMode) {
            playMode = allCases[(idx + 1) % allCases.count]
        }
    }

    func onSongEnded() { playNext() }

    func dismissError() {
        playbackError = nil
        audioService.cancelLoading()
        if playbackState == .failed {
            playbackState = selectedSong != nil ? .ready : .idle
        }
    }
}
