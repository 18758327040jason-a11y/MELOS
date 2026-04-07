import Foundation

enum YouTubeDownloadError: LocalizedError {
    case searchFailed
    case downloadFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .searchFailed: return "未找到该歌曲"
        case .downloadFailed(let msg): return "下载失败: \(msg)"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        }
    }
}

actor YouTubeMusicService {
    static let shared = YouTubeMusicService()

    private init() {}

    /// Search YouTube for a track and return the best matching video URL
    func search(query: String) async throws -> String {
        let safeQuery = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp")
        process.arguments = [
            "--no-playlist",
            "--print", "%(webpage_url)s",
            "--quiet",
            "--max-downloads", "1",
            "ytsearch1:\(query)"
        ]
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if output.isEmpty || output.contains("ERROR") {
            throw YouTubeDownloadError.searchFailed
        }

        // Filter to first line only
        let firstLine = output.components(separatedBy: .newlines).first ?? ""
        if firstLine.isEmpty || firstLine.contains("ERROR") {
            throw YouTubeDownloadError.searchFailed
        }

        return firstLine
    }

    /// Download audio from a YouTube URL to the given destination
    func download(url: String, to destination: URL, progressHandler: ((Double) -> Void)? = nil) async throws {
        let downloadDir = destination.deletingLastPathComponent()
        let tmpName = "tmp_\(UUID().uuidString)"

        let process = Process()
        let pipe = Pipe()
        let errPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp")
        process.arguments = [
            "--extract-audio",
            "--audio-format", "mp3",
            "--audio-quality", "0",
            "--output", "\(downloadDir.path)/\(tmpName).%(ext)s",
            "--quiet",
            "--no-playlist",
            url
        ]
        process.standardOutput = pipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let errOutput = String(data: errData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 || errOutput.contains("ERROR") {
            throw YouTubeDownloadError.downloadFailed(errOutput.prefix(200).description)
        }

        // Find the tmp file and rename to final destination
        let tmpURL = downloadDir.appendingPathComponent("\(tmpName).mp3")
        if FileManager.default.fileExists(atPath: tmpURL.path) {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tmpURL, to: destination)
        } else {
            // Fallback: find any recently downloaded mp3
            let files = (try? FileManager.default.contentsOfDirectory(at: downloadDir, includingPropertiesForKeys: [.creationDateKey])) ?? []
            let recent = files.filter { $0.pathExtension == "mp3" && !$0.lastPathComponent.hasPrefix("tmp_") }
                .sorted { f1, f2 in
                    let d1 = (try? f1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    let d2 = (try? f2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                    return d1 > d2
                }
            if let latest = recent.first {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: latest, to: destination)
            }
        }
    }
}
