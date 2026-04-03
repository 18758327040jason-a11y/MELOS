import Foundation
import SQLite

actor DatabaseService {
    static let shared = DatabaseService()

    private var db: Connection?

    // Tables
    private let playlists = Table("playlists")
    private let songs = Table("songs")

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

    private init() {}

    func initialize() async {
        do {
            let path = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            let dbPath = path.appendingPathComponent("MusicPlayer.sqlite").path
            db = try Connection(dbPath)
            try createTables()
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
        })
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
            sPlaylistId <- playlistId
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
                coverUrl: row[sCoverUrl]
            )
            result.append(song)
        }
        return result
    }
}
