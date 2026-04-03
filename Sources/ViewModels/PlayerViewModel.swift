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

@MainActor
class PlayerViewModel: ObservableObject {
    static let shared = PlayerViewModel()

    @Published var currentSong: Song?
    @Published var playMode: PlayMode = .sequential
    @Published var currentPlaylist: [Song] = []
    @Published var currentIndex: Int = -1

    let audioService = AudioPlayerService.shared

    var isPlaying: Bool { audioService.isPlaying }
    var currentTime: Double { audioService.currentTime }
    var duration: Double { audioService.duration }
    var volume: Double { audioService.volume }
    var isLoading: Bool { audioService.isLoading }

    private init() {}

    func play(song: Song, in playlist: [Song]) {
        currentPlaylist = playlist
        if let idx = playlist.firstIndex(of: song) {
            currentIndex = idx
        }
        currentSong = song
        audioService.play(song: song)
    }

    func playAt(index: Int) {
        guard index >= 0, index < currentPlaylist.count else { return }
        currentIndex = index
        let song = currentPlaylist[index]
        currentSong = song
        audioService.play(song: song)
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

    func togglePlayPause() {
        if currentSong != nil {
            audioService.togglePlayPause()
        }
    }

    func stop() {
        currentSong = nil
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

    // Called when current song ends
    func onSongEnded() {
        playNext()
    }
}
