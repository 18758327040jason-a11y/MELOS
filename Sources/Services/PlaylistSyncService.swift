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
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Origin")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "id=\(playlistId)".data(using: .utf8)
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)

        let rawString = String(data: data, encoding: .utf8) ?? ""
        print("[NetEase Playlist] raw: \(rawString.prefix(1000))")

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SyncError.parseError("无法解析网易云音乐响应 - JSON无效")
        }

        // result IS the playlist object directly (not result.playlist)
        guard let result = json["result"] as? [String: Any] else {
            print("[NetEase] JSON keys: \(json.keys)")
            throw SyncError.parseError("无法解析网易云音乐响应 - 找不到playlist数据")
        }

        let playlistName = result["name"] as? String ?? "网易云音乐歌单"
        var songs: [Song] = []

        // API returns full track objects in "tracks" field
        if let tracks = result["tracks"] as? [[String: Any]] {
            print("[NetEase] Found \(tracks.count) tracks in playlist")
            songs = tracks.prefix(100).compactMap { parseNetEaseSong($0) }
        } else if let trackIds = result["trackIds"] as? [[String: Any]] {
            print("[NetEase] No tracks, fetching \(trackIds.count) trackIds...")
            let ids = trackIds.prefix(100).compactMap { $0["id"] as? Int }
            if !ids.isEmpty {
                let trackList = try await fetchNetEaseTracks(ids: ids)
                print("[NetEase] fetchNetEaseTracks returned \(trackList.count) songs")
                songs = trackList
            }
        }

        // Get playlist cover (keep as-is)
        let playlistCoverUrl = (result["coverImgUrl"] as? String) ?? (result["picUrl"] as? String)

        return Playlist(
            id: "netease_\(playlistId)",
            platform: .netEase,
            name: playlistName,
            songCount: songs.count,
            lastSyncTime: Date(),
            songs: songs,
            coverUrl: playlistCoverUrl
        )
    }

    private func fetchNetEaseTracks(ids: [Int]) async throws -> [Song] {
        // Use song/-enhance/getplayerplayinfo API which returns full track info
        let apiURL = "https://music.163.com/api/song/player-detail"
        var request = URLRequest(url: URL(string: apiURL)!)
        request.httpMethod = "POST"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Origin")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let idsStr = ids.map { String($0) }.joined(separator: ",")
        request.httpBody = "ids=[\(idsStr)]&types=1".data(using: .utf8)
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)
        let raw = String(data: data, encoding: .utf8) ?? ""
        print("[NetEase Tracks] raw: \(raw.prefix(500))")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("[NetEase Tracks] JSON parse failed")
            return []
        }
        print("[NetEase Tracks] JSON keys: \(json.keys)")
        if let songs = json["songs"] as? [[String: Any]] {
            return songs.compactMap { parseNetEaseSong($0) }
        }
        return []
    }

    private func parseNetEaseSong(_ item: [String: Any]) -> Song? {
        guard let id = item["id"] as? Int,
              let name = item["name"] as? String else {
            return nil
        }

        // NetEase API uses full keys: artists, album, duration
        let artists = (item["artists"] as? [[String: Any]]) ?? []
        let artist = artists.map { $0["name"] as? String ?? "" }.joined(separator: ", ")
        let album = (item["album"] as? [String: Any])?["name"] as? String
        var coverUrl = (item["album"] as? [String: Any])?["picUrl"] as? String
        // Keep http URL as-is — some music.126.net URLs only work over http
        // duration is in milliseconds
        let duration = (item["duration"] as? Int ?? 0) / 1000

        // Play URL from outer URL endpoint (no auth needed, returns 302 redirect to CDN)
        let playUrl = "https://music.163.com/song/media/outer/url?id=\(id)"

        return Song(
            id: "netease_\(id)",
            platform: .netEase,
            title: name,
            artist: artist.isEmpty ? "未知艺术家" : artist,
            album: album,
            duration: duration,
            playUrl: playUrl,
            coverUrl: coverUrl
        )
    }
}
