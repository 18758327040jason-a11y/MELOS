import AVFoundation
import Combine
import SwiftUI

@MainActor
class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    private var player: AVPlayer?
    private var audioPlayer: AVAudioPlayer?
    private var timeObserver: Any?
    private var audioPlayerTimer: Timer?
    private var playbackCompletion: ((Bool, String?) -> Void)?
    private var cancellables = Set<AnyCancellable>()
    var onSongFinished: (() -> Void)?

    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = 0.8
    @Published var isLoading: Bool = false

    private(set) var currentSong: Song?

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

    // ── Local file priority playback URL resolution ──
    private func playbackURL(for song: Song) -> URL? {
        if let localURL = DownloadService.shared.localPath(for: song.id) {
            logToFile("[AudioService] local: \(localURL.path)")
            return localURL
        }
        if let urlString = resolvedStreamingURL(for: song), !urlString.isEmpty {
            logToFile("[AudioService] stream: \(urlString)")
            return URL(string: urlString)
        }
        return nil
    }

    private func resolvedStreamingURL(for song: Song) -> String? {
        if let existing = song.playUrl, !existing.isEmpty { return existing }
        switch song.platform {
        case .netEase:
            let id = song.id.replacingOccurrences(of: "netease_", with: "")
            return "https://music.163.com/song/media/outer/url?id=\(id)"
        case .qq:
            let id = song.id.replacingOccurrences(of: "qq_", with: "")
            return "https://dl.stream.qqmusic.qq.com/C100\(id).m4a?fromtag=0&guid=0"
        }
    }

    func startPlayback(song: Song, completion: @escaping (Bool, String?) -> Void) {
        logToFile("[AudioService] startPlayback: \(song.title)")

        guard let url = playbackURL(for: song) else {
            isLoading = false
            completion(false, "无可用播放地址")
            return
        }

        // Same song + same local file: resume without rebuilding player
        if song.id == currentSong?.id, audioPlayer != nil, url.isFileURL {
            logToFile("[AudioService] same song local — resume")
            playbackCompletion = completion
            audioPlayer?.volume = Float(volume)
            audioPlayer?.play()
            isPlaying = true
            isLoading = false
            duration = audioPlayer?.duration ?? 0
            completion(true, nil)
            startAudioPlayerTimer()
            return
        }

        playbackCompletion = nil
        stopSilently()

        currentSong = song
        isLoading = true
        playbackCompletion = completion

        logToFile("[AudioService] url=\(url.absoluteString) local=\(url.isFileURL)")

        // ── Local file: AVAudioPlayer ──
        if url.isFileURL {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.volume = Float(volume)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                isPlaying = true
                isLoading = false
                duration = audioPlayer?.duration ?? 0
                currentTime = 0
                logToFile("[AudioService] AVAudioPlayer playing duration=\(duration)")
                completion(true, nil)
                startAudioPlayerTimer()
            } catch {
                isLoading = false
                completion(false, error.localizedDescription)
            }
            return
        }

        // ── Streaming: AVPlayer ──
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = Float(volume)

        var timerFired = false
        let timer = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isLoading, !timerFired else { return }
                timerFired = true
                self.cleanupPlayer()
                self.isLoading = false
                self.isPlaying = false
                self.playbackCompletion?(false, "网络超时，播放失败")
                self.playbackCompletion = nil
            }
        }

        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self, !timerFired else { return }
                timer.invalidate()
                switch status {
                case .readyToPlay:
                    self.player?.play()
                    self.isPlaying = true
                    self.isLoading = false
                    let d = playerItem.duration.seconds
                    self.duration = d.isNaN ? 0 : d
                    self.playbackCompletion?(true, nil)
                    self.playbackCompletion = nil
                    self.startTimeObserver()
                case .failed:
                    self.isLoading = false
                    self.isPlaying = false
                    self.playbackCompletion?(false, playerItem.error?.localizedDescription ?? "加载失败")
                    self.playbackCompletion = nil
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.onSongFinished?()
            }
        }

        Task {
            if let dur = try? await asset.load(.duration) {
                await MainActor.run {
                    let d = dur.seconds
                    if !d.isNaN { self.duration = d }
                }
            }
        }
    }

    // ── Local file polling ──
    private func startAudioPlayerTimer() {
        audioPlayerTimer?.invalidate()
        audioPlayerTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let ap = self.audioPlayer else { return }
                self.currentTime = ap.currentTime
                self.duration = ap.duration
                self.objectWillChange.send()
                if !ap.isPlaying && self.isPlaying {
                    self.isPlaying = false
                    self.audioPlayerTimer?.invalidate()
                    self.audioPlayerTimer = nil
                    self.onSongFinished?()
                }
            }
        }
    }

    private func cleanupPlayer() {
        removeTimeObserver()
        cancellables.removeAll()
        player?.pause()
        player = nil
    }

    func pause() {
        audioPlayer?.pause()
        player?.pause()
        isPlaying = false
    }

    func cancelLoading() {
        isLoading = false
    }

    func resume() {
        audioPlayer?.play()
        player?.play()
        isPlaying = true
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    private func stopSilently() {
        audioPlayerTimer?.invalidate()
        audioPlayerTimer = nil
        removeTimeObserver()
        audioPlayer?.stop()
        audioPlayer = nil
        cleanupPlayer()
        isPlaying = false
        currentTime = 0
        duration = 0
        currentSong = nil
        isLoading = false
        cancellables.removeAll()
    }

    func stop() {
        stopSilently()
        if let cb = playbackCompletion { cb(false, "播放已停止") }
        playbackCompletion = nil
    }

    func seek(to seconds: Double) {
        audioPlayer?.currentTime = seconds
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        currentTime = seconds
    }

    func setVolume(_ value: Double) {
        volume = value
        audioPlayer?.volume = Float(value)
        player?.volume = Float(value)
        UserDefaults.standard.set(value, forKey: "playerVolume")
    }

    private func startTimeObserver() {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.033, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds
                self.objectWillChange.send()
            }
        }
    }

    private func removeTimeObserver() {
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
    }
}
