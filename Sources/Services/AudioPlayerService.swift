import AVFoundation
import Combine
import SwiftUI

@MainActor
class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    private var player: AVPlayer?
    private var timeObserver: Any?

    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = 0.8
    @Published var isLoading: Bool = false

    private var currentSong: Song?

    private init() {
        setupAudioSession()
        setupVolumeObserver()
    }

    private func setupAudioSession() {
        // macOS does not use AVAudioSession — this is iOS-only
        // Audio playback on macOS via AVPlayer requires no session setup
    }

    private func setupVolumeObserver() {
        if let observer = UserDefaults.standard.object(forKey: "playerVolume") as? Double {
            volume = observer
        }
    }

    func play(song: Song) {
        guard let urlString = song.playUrl, let url = URL(string: urlString) else {
            print("No valid play URL for song: \(song.title)")
            return
        }

        stop()
        currentSong = song
        isLoading = true

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = Float(volume)

        // Observe duration
        Task {
            if let durationCM = try? await asset.load(.duration) {
                await MainActor.run {
                    self.duration = durationCM.seconds
                }
            }
        }

        // Observe status
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }

        player?.play()
        isPlaying = true
        isLoading = false

        startTimeObserver()
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        player?.play()
        isPlaying = true
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
