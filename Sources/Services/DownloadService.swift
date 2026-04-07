import Foundation

/// Stores the mapping of song IDs to their downloaded local file paths
struct DownloadRecord: Codable {
    let songId: String
    let platform: String
    let localPath: String
    let downloadedAt: Date
}

enum DownloadError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case noContentDisposition
    case fileSystemError(Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的下载地址"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        case .noContentDisposition: return "无法获取文件名"
        case .fileSystemError(let e): return "文件保存失败: \(e.localizedDescription)"
        case .cancelled: return "下载已取消"
        }
    }
}

struct DownloadItem: Identifiable, Equatable {
    let id: UUID
    let url: String
    let fileName: String
    let destinationPath: String
    var state: DownloadState
    var progress: Double
    var error: String?

    enum DownloadState: Equatable {
        case pending
        case downloading
        case completed
        case failed
        case cancelled
    }
}

@MainActor
class DownloadService: ObservableObject {
    static let shared = DownloadService()

    @Published var items: [DownloadItem] = []
    @Published var showingSheet: Bool = false

    private var activeDownloads: [UUID: URLSessionDownloadTask] = [:]
    private var observation: NSKeyValueObservation?

    static let downloadDirectory: URL = {
        let dir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Documents/program/MusicPlayer/download")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private let recordKey = "downloadedSongs_v1"

    private func saveRecord(_ record: DownloadRecord) {
        var records = loadRecords()
        records.removeAll { $0.songId == record.songId }
        records.append(record)
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: recordKey)
        }
    }

    func loadRecords() -> [DownloadRecord] {
        guard let data = UserDefaults.standard.data(forKey: recordKey),
              let records = try? JSONDecoder().decode([DownloadRecord].self, from: data) else {
            return []
        }
        return records
    }

    func localPath(for songId: String) -> URL? {
        let normalizedId = songId.replacingOccurrences(of: "netease_", with: "")
            .replacingOccurrences(of: "qq_", with: "")
        let records = loadRecords()
        let matching = records.filter {
            $0.songId == songId ||
            $0.songId == "netease_\(normalizedId)" ||
            $0.songId == "qq_\(normalizedId)"
        }
        if let record = matching.first {
            let url = URL(fileURLWithPath: record.localPath)
            let exists = FileManager.default.fileExists(atPath: record.localPath)
            logToFile("[DownloadService] localPath for '\(songId)': \(record.localPath), exists: \(exists)")
            return exists ? url : nil
        }
        logToFile("[DownloadService] localPath for '\(songId)': NOT FOUND")

        // Fallback: scan download directory for files matching songId
        let normalized = songId.replacingOccurrences(of: "netease_", with: "")
            .replacingOccurrences(of: "qq_", with: "")
        let prefixes = ["netease_\(normalized)", "qq_\(normalized)", normalized]
        if let files = try? FileManager.default.contentsOfDirectory(at: Self.downloadDirectory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "mp3" {
                let name = file.deletingPathExtension().lastPathComponent
                if prefixes.contains(name) {
                    logToFile("[DownloadService] fallback found: \(file.path)")
                    return file
                }
            }
        }
        return nil
    }

    /// Synchronously check if a song has a local downloaded file
    /// Handles both prefixed (netease_xxx) and plain (xxx) song IDs
    func isDownloaded(_ songId: String) -> Bool {
        let normalizedId = songId.replacingOccurrences(of: "netease_", with: "")
            .replacingOccurrences(of: "qq_", with: "")
        guard let data = UserDefaults.standard.data(forKey: recordKey),
              let records = try? JSONDecoder().decode([DownloadRecord].self, from: data) as [DownloadRecord],
              let record = records.first(where: {
                  $0.songId == songId ||
                  $0.songId == "netease_\(normalizedId)" ||
                  $0.songId == "qq_\(normalizedId)"
              }) else {
            // Fallback: check if file exists in download directory
            let prefixes = ["netease_\(normalizedId)", "qq_\(normalizedId)", normalizedId]
            if let files = try? FileManager.default.contentsOfDirectory(at: Self.downloadDirectory, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "mp3" {
                    let name = file.deletingPathExtension().lastPathComponent
                    if prefixes.contains(name) { return true }
                }
            }
            return false
        }
        return FileManager.default.fileExists(atPath: record.localPath)
    }

    private func logToFile(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        try? line.write(toFile: "/tmp/musicplayer_debug.log", atomically: true, encoding: .utf8)
    }

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config, delegate: nil, delegateQueue: .main)
    }()

    private init() {}

    func download(from urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw DownloadError.invalidURL
        }

        // Derive filename from Content-Disposition header or URL
        var fileName = URLSession.shared.description
        let tempReq = URLRequest(url: url)
        // Attempt to get a better name from the URL
        fileName = url.lastPathComponent.isEmpty ? "download_\(UUID().uuidString)" : url.lastPathComponent

        // If duplicate filename exists, append counter
        var destination = Self.downloadDirectory.appendingPathComponent(fileName)
        var counter = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            let name = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            destination = Self.downloadDirectory.appendingPathComponent("\(name)_\(counter).\(ext)")
            counter += 1
        }

        let item = DownloadItem(
            id: UUID(),
            url: urlString,
            fileName: fileName,
            destinationPath: destination.path,
            state: .downloading,
            progress: 0,
            error: nil
        )
        items.append(item)

        do {
            let (tempURL, response) = try await session.download(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw DownloadError.networkError(URLError(.badServerResponse))
            }

            try FileManager.default.moveItem(at: tempURL, to: destination)

            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].state = .completed
                items[idx].progress = 1.0
            }

            // Save record: strip extension so songId matches playlist format (e.g. netease_33285928)
            let songId = destination.deletingPathExtension().lastPathComponent
            let record = DownloadRecord(
                songId: songId,
                platform: "local",
                localPath: destination.path,
                downloadedAt: Date()
            )
            saveRecord(record)

            return destination
        } catch {
            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                items[idx].state = .failed
                items[idx].error = error.localizedDescription
            }
            throw error
        }
    }

    func cancelDownload(id: UUID) {
        activeDownloads[id]?.cancel()
        activeDownloads.removeValue(forKey: id)
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items[idx].state = .cancelled
        }
    }

    func clearCompleted() {
        items.removeAll { $0.state == .completed || $0.state == .cancelled || $0.state == .failed }
    }
}
