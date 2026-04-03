import Foundation
import SQLite

actor DatabaseService {
    static let shared = DatabaseService()

    private var db: Connection?

    // Tables
    private let playlists = Table("playlists")
    private let songs = Table("songs")
    private let history = Table("history")

    // Playlist columns
    private let pId = SQLite.Expression<String>("id")
    private let pPlatform = SQLite.Expression<String>("platform")
    private let pName = SQLite.Expression<String>("name")
    private let pSongCount = SQLite.Expression<Int>("song_count")
    private let pLastSync = SQLite.Expression<Double?>("last_sync")

    // Song columns
    private let sId = SQLite.Expression<String>("id")
    private let sPlatform = SQLite.Expression<String>("platform")
    private let sTitle = SQLite.Expression<String>("title")
    private let sArtist = SQLite.Expression<String>("artist")
    private let sAlbum = SQLite.Expression<String?>("album")
    private let sDuration = SQLite.Expression<Int>("duration")
    private let sPlayUrl = SQLite.Expression<String?>("play_url")
    private let sCoverUrl = SQLite.Expression<String?>("cover_url")
    private let sPlaylistId = SQLite.Expression<String>("playlist_id")
    private let sIsFavorite = SQLite.Expression<Bool>("is_favorite")

    // History columns
    private let hId = SQLite.Expression<String>("id")
    private let hSongId = SQLite.Expression<String>("song_id")
    private let hPlatform = SQLite.Expression<String>("platform")
    private let hTitle = SQLite.Expression<String>("title")
    private let hArtist = SQLite.Expression<String>("artist")
    private let hAlbum = SQLite.Expression<String?>("album")
    private let hDuration = SQLite.Expression<Int>("duration")
    private let hPlayUrl = SQLite.Expression<String?>("play_url")
    private let hCoverUrl = SQLite.Expression<String?>("cover_url")
    private let hPlayedAt = SQLite.Expression<Double>("played_at")

    private init() {}

    func initialize() async {
        do {
            let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            let dbPath = path.appendingPathComponent("MusicPlayer.sqlite").path
            db = try Connection(dbPath)
            try createTables()
            try migrateAddIsFavorite()
        } catch {
            print("Database init error: \(error)")
        }
    }

    private func createTables() throws {
        try db?.run(playlists.create(ifNotExists: true) { t in
            t.column(pId, primaryKey: true)
            t.column(pPlatform)
            t.column(pName)
            t.column(pSongCount)
            t.column(pLastSync)
        })

        try db?.run(songs.create(ifNotExists: true) { t in
            t.column(sId, primaryKey: true)
            t.column(sPlatform)
            t.column(sTitle)
            t.column(sArtist)
            t.column(sAlbum)
            t.column(sDuration)
            t.column(sPlayUrl)
            t.column(sCoverUrl)
            t.column(sPlaylistId)
            t.column(sIsFavorite, defaultValue: false)
        })

        try db?.run(history.create(ifNotExists: true) { t in
            t.column(hId, primaryKey: true)
            t.column(hSongId)
            t.column(hPlatform)
            t.column(hTitle)
            t.column(hArtist)
            t.column(hAlbum)
            t.column(hDuration)
            t.column(hPlayUrl)
            t.column(hCoverUrl)
            t.column(hPlayedAt)
        })
    }

    private func migrateAddIsFavorite() throws {
        guard let db = db else { return }
        let stmt = try db.prepare("PRAGMA table_info(songs)")
        var columnNames: [String] = []
        for row in stmt {
            if let name = row[1] as? String {
                columnNames.append(name)
            }
        }
        if !columnNames.contains("is_favorite") {
            try db.run("ALTER TABLE songs ADD COLUMN is_favorite INTEGER DEFAULT 0")
        }
    }

    // MARK: - Playlist CRUD

    func savePlaylist(_ playlist: Playlist) async throws {
        let insert = playlists.insert(or: .replace,
            pId <- playlist.id,
            pPlatform <- playlist.platform.rawValue,
            pName <- playlist.name,
            pSongCount <- playlist.songs.count,
            pLastSync <- playlist.lastSyncTime?.timeIntervalSince1970
        )
        try db?.run(insert)

        for song in playlist.songs {
            try await saveSong(song, playlistId: playlist.id)
        }
    }

    func loadPlaylists() async throws -> [Playlist] {
        guard let db = db else { return [] }
        var result: [Playlist] = []

        for row in try db.prepare(playlists) {
            let pid = row[pId]
            let platformStr = row[pPlatform]
            let platform = Platform(rawValue: platformStr) ?? .qq
            let lastSync = row[pLastSync].map { Date(timeIntervalSince1970: $0) }
            let playlistSongs = try await loadSongs(playlistId: pid)

            let playlist = Playlist(
                id: pid,
                platform: platform,
                name: row[pName],
                songCount: row[pSongCount],
                lastSyncTime: lastSync,
                songs: playlistSongs
            )
            result.append(playlist)
        }
        return result
    }

    func deletePlaylist(id: String) async throws {
        let q = playlists.filter(pId == id)
        try db?.run(q.delete())
        let sq = songs.filter(sPlaylistId == id)
        try db?.run(sq.delete())
    }

    // MARK: - Song CRUD

    private func saveSong(_ song: Song, playlistId: String) async throws {
        let insert = songs.insert(or: .replace,
            sId <- song.id,
            sPlatform <- song.platform.rawValue,
            sTitle <- song.title,
            sArtist <- song.artist,
            sAlbum <- song.album,
            sDuration <- song.duration,
            sPlayUrl <- song.playUrl,
            sCoverUrl <- song.coverUrl,
            sPlaylistId <- playlistId,
            sIsFavorite <- song.isFavorite
        )
        try db?.run(insert)
    }

    private func loadSongs(playlistId: String) async throws -> [Song] {
        guard let db = db else { return [] }
        var result: [Song] = []
        let q = songs.filter(sPlaylistId == playlistId)

        for row in try db.prepare(q) {
            let platform = Platform(rawValue: row[sPlatform]) ?? .qq
            let song = Song(
                id: row[sId],
                platform: platform,
                title: row[sTitle],
                artist: row[sArtist],
                album: row[sAlbum],
                duration: row[sDuration],
                playUrl: row[sPlayUrl],
                coverUrl: row[sCoverUrl],
                isFavorite: row[sIsFavorite]
            )
            result.append(song)
        }
        return result
    }

    // MARK: - Favorites

    func toggleFavorite(songId: String) async throws -> Bool {
        guard let db = db else { return false }
        let songRow = songs.filter(sId == songId)
        if let row = try db.pluck(songRow) {
            let current = row[sIsFavorite]
            try db.run(songRow.update(sIsFavorite <- !current))
            return !current
        }
        return false
    }

    func loadFavorites() async throws -> [Song] {
        guard let db = db else { return [] }
        var result: [Song] = []
        let q = songs.filter(sIsFavorite == true)
        for row in try db.prepare(q) {
            let platform = Platform(rawValue: row[sPlatform]) ?? .qq
            let song = Song(
                id: row[sId], platform: platform,
                title: row[sTitle], artist: row[sArtist],
                album: row[sAlbum], duration: row[sDuration],
                playUrl: row[sPlayUrl], coverUrl: row[sCoverUrl],
                isFavorite: true
            )
            result.append(song)
        }
        return result
    }

    // MARK: - History

    func addToHistory(_ song: Song) async throws {
        let id = UUID().uuidString
        let insert = history.insert(
            hId <- id,
            hSongId <- song.id,
            hPlatform <- song.platform.rawValue,
            hTitle <- song.title,
            hArtist <- song.artist,
            hAlbum <- song.album,
            hDuration <- song.duration,
            hPlayUrl <- song.playUrl,
            hCoverUrl <- song.coverUrl,
            hPlayedAt <- Date().timeIntervalSince1970
        )
        try db?.run(insert)
        // Keep last 200 entries
        try db?.run("DELETE FROM history WHERE id NOT IN (SELECT id FROM history ORDER BY played_at DESC LIMIT 200)")
    }

    func loadHistory(limit: Int = 100) async throws -> [Song] {
        guard let db = db else { return [] }
        var result: [Song] = []
        let q = history.order(hPlayedAt.desc).limit(limit)
        for row in try db.prepare(q) {
            let platform = Platform(rawValue: row[hPlatform]) ?? .qq
            let song = Song(
                id: row[hSongId], platform: platform,
                title: row[hTitle], artist: row[hArtist],
                album: row[hAlbum], duration: row[hDuration],
                playUrl: row[hPlayUrl], coverUrl: row[hCoverUrl]
            )
            result.append(song)
        }
        return result
    }
}
