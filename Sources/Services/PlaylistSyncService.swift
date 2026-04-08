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

        // Use yt-dlp to get full playlist (API only returns 10 tracks)
        let playlistURLFragment = "https://music.163.com/#/playlist?id=\(playlistId)"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp")
        process.arguments = ["--flat-playlist", "--print", "%(title)s | %(duration)s | %(id)s", playlistURLFragment]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outData, encoding: .utf8) else {
            throw SyncError.parseError("无法读取 yt-dlp 输出")
        }

        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        print("[NetEase] yt-dlp returned \(lines.count) songs")

        var songs: [Song] = []
        var firstCoverUrl: String?

        for line in lines where !line.isEmpty {
            // Format: "title | duration | id" (duration may be empty string if unavailable)
            let parts = line.split(separator: "|", maxSplits: 2).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 3, let songId = Int(parts[2]) else { continue }
            let title = parts[0]
            let duration = Int(parts[1]) ?? 0
            let netEaseURL = "https://music.163.com/#/song?id=\(songId)"

            if firstCoverUrl == nil {
                let coverProc = Process()
                coverProc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp")
                coverProc.arguments = ["--print", "%(thumbnail)s", "--single-video", netEaseURL]
                let coverPipe = Pipe()
                coverProc.standardOutput = coverPipe
                coverProc.standardError = FileHandle.nullDevice
                try? coverProc.run()
                coverProc.waitUntilExit()
                let coverData = coverPipe.fileHandleForReading.readDataToEndOfFile()
                firstCoverUrl = String(data: coverData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let song = Song(
                id: "netease_\(songId)",
                platform: .netEase,
                title: title,
                artist: "网易云音乐",
                album: "网易云音乐歌单",
                duration: duration,
                playUrl: netEaseURL,
                coverUrl: nil
            )
            songs.append(song)
        }

        // Get playlist name from yt-dlp
        let nameProc = Process()
        nameProc.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/yt-dlp")
        nameProc.arguments = ["--print", "%(playlist_title)s", "--playlist-items", "1", playlistURLFragment]
        let namePipe = Pipe()
        nameProc.standardOutput = namePipe
        nameProc.standardError = FileHandle.nullDevice
        try? nameProc.run()
        nameProc.waitUntilExit()
        let nameData = namePipe.fileHandleForReading.readDataToEndOfFile()
        let playlistName = String(data: nameData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "网易云音乐歌单"

        return Playlist(
            id: "netease_\(playlistId)",
            platform: .netEase,
            name: playlistName,
            lastSyncTime: Date(),
            songs: songs,
            coverUrl: firstCoverUrl
        )
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
