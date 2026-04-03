import AVFoundation
import Combine
import SwiftUI

@MainActor
class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var playbackCompletion: ((Bool, String?) -> Void)?

    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = 0.8
    @Published var isLoading: Bool = false

    private var currentSong: Song?

    private let logPath = "/tmp/musicplayer_debug.log"

    private init() {
        try? "".write(toFile: "/tmp/musicplayer_debug.log", atomically: true, encoding: .utf8)
        if let savedVolume = UserDefaults.standard.object(forKey: "playerVolume") as? Double {
            volume = savedVolume
        }
    }

    private func logToFile(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        try? line.write(toFile: "/tmp/musicplayer_debug.log", atomically: true, encoding: .utf8)
    }

    func startPlayback(song: Song, completion: @escaping (Bool, String?) -> Void) {
        playbackCompletion = completion

        let playUrlString: String = {
            if let existing = song.playUrl, !existing.isEmpty {
                return existing
            }
            switch song.platform {
            case .netEase:
                let id = song.id.replacingOccurrences(of: "netease_", with: "")
                return "https://music.163.com/song/media/outer/url?id=\(id)"
            case .qq:
                let id = song.id.replacingOccurrences(of: "qq_", with: "")
                return "https://dl.stream.qqmusic.qq.com/C100\(id).m4a?fromtag=0&guid=0"
            }
        }()

        logToFile("[AudioService] startPlayback: \(song.title) | url: \(playUrlString)")

        guard let url = URL(string: playUrlString) else {
            logToFile("[AudioService] ERROR: invalid URL")
            completion(false, "播放地址无效")
            playbackCompletion = nil
            return
        }

        stop()
        currentSong = song
        isLoading = true

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = Float(volume)

        // Monitor status with timeout fallback
        let timer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.isLoading {
                    self.isLoading = false
                    let msg = "网络超时，播放失败"
                    self.logToFile("[AudioService] TIMEOUT: \(msg)")
                    self.playbackCompletion?(false, msg)
                    self.playbackCompletion = nil
                }
            }
        }

        // Status observer
        let observer = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self = self else { return }
                timer.invalidate()
                switch item.status {
                case .readyToPlay:
                    self.player?.play()
                    self.isPlaying = true
                    self.isLoading = false
                    self.logToFile("[AudioService] readyToPlay -> started")
                    self.playbackCompletion?(true, nil)
                    self.playbackCompletion = nil
                case .failed:
                    self.isLoading = false
                    self.isPlaying = false
                    let err = item.error?.localizedDescription ?? "加载失败"
                    self.logToFile("[AudioService] failed: \(err)")
                    self.playbackCompletion?(false, err)
                    self.playbackCompletion = nil
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        // End-of-track
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }

        // Duration
        Task {
            if let durationCM = try? await asset.load(.duration) {
                await MainActor.run {
                    self.duration = durationCM.seconds
                }
            }
        }

        startTimeObserver()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        logToFile("[AudioService] paused")
    }

    func cancelLoading() {
        isLoading = false
        logToFile("[AudioService] cancelLoading: isLoading=false")
    }

    func resume() {
        player?.play()
        isPlaying = true
        logToFile("[AudioService] resumed")
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func stop() {
        removeTimeObserver()
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentSong = nil
        playbackCompletion?(false, "播放已停止")
        playbackCompletion = nil
    }

    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
        currentTime = seconds
    }

    func setVolume(_ value: Double) {
        volume = value
        player?.volume = Float(value)
        UserDefaults.standard.set(value, forKey: "playerVolume")
    }

    private func startTimeObserver() {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
}
