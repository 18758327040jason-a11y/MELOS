import Foundation

enum SyncError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parseError(String)
    case platformNotSupported

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的歌单链接"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        case .parseError(let s): return "解析失败: \(s)"
        case .platformNotSupported: return "不支持的平台"
        }
    }
}

actor PlaylistSyncService {
    static let shared = PlaylistSyncService()

    private init() {}

    // MARK: - Public API

    func syncPlaylist(from url: String) async throws -> Playlist {
        if url.contains("y.qq.com") || url.contains("qq.com") {
            return try await syncQQMusic(playlistURL: url)
        } else if url.contains("music.163.com") || url.contains("y.music.163") {
            return try await syncNetEaseMusic(playlistURL: url)
        } else {
            throw SyncError.platformNotSupported
        }
    }

    // MARK: - QQ Music

    private func syncQQMusic(playlistURL: String) async throws -> Playlist {
        guard let playlistId = Platform.qq.playlistIDFromURL(playlistURL) else {
            throw SyncError.invalidURL
        }

        let apiURL = "https://c.y.qq.com/qzone/fcg-bin/fcg_ucc_getcdinfo_byids_cp.fcg"
        var components = URLComponents(string: apiURL)!
        components.queryItems = [
            URLQueryItem(name: "disstid", value: playlistId),
            URLQueryItem(name: "type", value: "1"),
            URLQueryItem(name: "utf", value: "1"),
            URLQueryItem(name: "format", value: "json")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)

        // QQ music response parsing - simplified JSON structure
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cdlist = json["cdlist"] as? [[String: Any]],
              let cdInfo = cdlist.first else {
            throw SyncError.parseError("无法解析QQ音乐响应")
        }

        let playlistName = cdInfo["dissname"] as? String ?? "QQ音乐歌单"
        let playlistid = cdInfo["disstid"] as? String ?? playlistId

        var songs: [Song] = []
        if let songlist = cdInfo["songlist"] as? [[String: Any]] {
            for item in songlist {
                guard let song = parseQQSong(item) else { continue }
                songs.append(song)
            }
        }

        return Playlist(
            id: "qq_\(playlistid)",
            platform: .qq,
            name: playlistName,
            songCount: songs.count,
            lastSyncTime: Date(),
            songs: songs
        )
    }

    private func parseQQSong(_ item: [String: Any]) -> Song? {
        guard let songmid = item["songmid"] as? String,
              let songName = (item["songname"] as? String) ?? (item["songname_hilight"] as? String) else {
            return nil
        }

        let singers = (item["singer"] as? [[String: Any]]) ?? []
        let artist = singers.map { $0["name"] as? String ?? "" }.joined(separator: ", ")
        let album = (item["albumname"] as? String)?.isEmpty == false ? item["albumname"] as? String : nil
        let interval = item["interval"] as? Int ?? 0
        let coverUrl = "https://y.gtimg.cn/music/photo_new/T002R300x300M000\(item["albummid"] as? String ?? "").jpg"
        let playUrl = "https://dl.stream.qqmusic.qq.com/C100\(songmid).m4a?fromtag=0&guid=0"

        return Song(
            id: "qq_\(songmid)",
            platform: .qq,
            title: songName,
            artist: artist.isEmpty ? "未知艺术家" : artist,
            album: album,
            duration: interval,
            playUrl: playUrl,
            coverUrl: coverUrl
        )
    }

    // MARK: - NetEase Music

    private func syncNetEaseMusic(playlistURL: String) async throws -> Playlist {
        guard let playlistId = Platform.netEase.playlistIDFromURL(playlistURL) else {
            throw SyncError.invalidURL
        }

        let apiURL = "https://music.163.com/api/playlist/detail"
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "id=\(playlistId)".data(using: .utf8)
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let playlist = json["result"] as? [String: Any] else {
            throw SyncError.parseError("无法解析网易云音乐响应")
        }

        let playlistName = playlist["name"] as? String ?? "网易云音乐歌单"
        var songs: [Song] = []

        if let trackIds = playlist["trackIds"] as? [[String: Any]] {
            // Batch fetch track details (max 100 per request for NetEase)
            let ids = trackIds.prefix(100).compactMap { $0["id"] as? Int }
            if !ids.isEmpty {
                let trackList = try await fetchNetEaseTracks(ids: ids)
                songs = trackList
            }
        }

        return Playlist(
            id: "netease_\(playlistId)",
            platform: .netEase,
            name: playlistName,
            songCount: songs.count,
            lastSyncTime: Date(),
            songs: songs
        )
    }

    private func fetchNetEaseTracks(ids: [Int]) async throws -> [Song] {
        let apiURL = "https://music.163.com/api/song/detail"
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let idsStr = ids.map { String($0) }.joined(separator: ",")
        request.httpBody = "ids=[\(idsStr)]".data(using: .utf8)
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let songList = json["songs"] as? [[String: Any]] else {
            return []
        }

        return songList.compactMap { parseNetEaseSong($0) }
    }

    private func parseNetEaseSong(_ item: [String: Any]) -> Song? {
        guard let id = item["id"] as? Int,
              let name = item["name"] as? String else {
            return nil
        }

        let artists = (item["artists"] as? [[String: Any]]) ?? (item["album"] as? [String: Any])?["artist"] as? [[String: Any]] ?? []
        let artist = artists.map { $0["name"] as? String ?? "" }.joined(separator: ", ")
        let album = (item["album"] as? [String: Any])?["name"] as? String
        let duration = (item["duration"] as? Int ?? 0) / 1000
        let coverUrl = (item["album"] as? [String: Any])?["picUrl"] as? String

        return Song(
            id: "netease_\(id)",
            platform: .netEase,
            title: name,
            artist: artist.isEmpty ? "未知艺术家" : artist,
            album: album,
            duration: duration,
            playUrl: nil,
            coverUrl: coverUrl
        )
    }
}
