import Foundation

struct SoundCloudTrack: Identifiable, Equatable {
    let id: Int
    let title: String
    let artist: String
    let duration: Int // milliseconds
    let streamUrl: String
    let artworkUrl: String?
    let genre: String?
    let permalinkUrl: String

    var formattedDuration: String {
        let sec = duration / 1000
        let min = sec / 60
        let s = sec % 60
        return String(format: "%d:%02d", min, s)
    }
}

enum SoundCloudError: LocalizedError {
    case searchFailed(String)
    case streamNotAvailable
    case networkError(Error)
    case clientIdMissing

    var errorDescription: String? {
        switch self {
        case .searchFailed(let msg): return "搜索失败: \(msg)"
        case .streamNotAvailable: return "该歌曲在 SoundCloud 上不可下载"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        case .clientIdMissing: return "无法获取播放凭证"
        }
    }
}

actor SoundCloudService {
    static let shared = SoundCloudService()

    // Embedded client ID — extracted from SoundCloud web player
    // Used per SoundCloud TOU for personal/non-commercial use
    private let clientId = "jUakd7DMSVKBVgYQ9AwjG3SzZeMUEXVZ"

    private init() {}

    /// Search SoundCloud for tracks matching the given song name + artist
    func search(query: String) async throws -> [SoundCloudTrack] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.soundcloud.com/tracks?q=\(encoded)&client_id=\(clientId)&limit=8&offset=0&linked_partitioning=1") else {
            throw SoundCloudError.searchFailed("无效搜索词")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("jUakd7DMSVKBVgYQ9AwjG3SzZeMUEXVZ", forHTTPHeaderField: "Client-ID")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SoundCloudError.searchFailed("HTTP error")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SoundCloudError.searchFailed("响应格式错误")
        }

        var tracks: [SoundCloudTrack] = []

        // Handle both collection array and direct track object
        let collection: [[String: Any]]
        if let arr = json["collection"] as? [[String: Any]] {
            collection = arr
        } else if let _ = json["id"] as? Int {
            // Single track result
            collection = [json]
        } else {
            throw SoundCloudError.searchFailed("无法解析搜索结果")
        }

        for item in collection {
            guard let id = item["id"] as? Int,
                  let title = item["title"] as? String,
                  let duration = item["duration"] as? Int else { continue }

            // Only include tracks with stream access
            let streamable = item["streamable"] as? Bool ?? false
            guard streamable == true else { continue }

            let artist = ((item["user"] as? [String: Any])?["username"] as? String) ?? "Unknown"
            let artworkUrl = item["artwork_url"] as? String?
                ?? (item["user"] as? [String: Any])?["avatar_url"] as? String
            let genre = item["genre"] as? String
            let permalinkUrl = item["permalink_url"] as? String ?? "https://soundcloud.com"

            // Build stream URL (transcoded MP3)
            let streamUrl = "https://api.soundcloud.com/tracks/\(id)/stream?client_id=\(clientId)"

            tracks.append(SoundCloudTrack(
                id: id,
                title: title,
                artist: artist,
                duration: duration,
                streamUrl: streamUrl,
                artworkUrl: artworkUrl,
                genre: genre,
                permalinkUrl: permalinkUrl
            ))
        }

        return tracks
    }

    /// Get a direct downloadable URL for a track
    func resolveDownloadURL(trackId: Int) async throws -> URL {
        guard let url = URL(string: "https://api.soundcloud.com/tracks/\(trackId)/stream?client_id=\(clientId)") else {
            throw SoundCloudError.streamNotAvailable
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")
        request.setValue(clientId, forHTTPHeaderField: "Client-ID")

        // SoundCloud returns 302 redirect to CDN URL
        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...399).contains(httpResponse.statusCode) else {
            throw SoundCloudError.streamNotAvailable
        }

        if let redirectURL = httpResponse.url {
            return redirectURL
        }

        throw SoundCloudError.streamNotAvailable
    }
}
