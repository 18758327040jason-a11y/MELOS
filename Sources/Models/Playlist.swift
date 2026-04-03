import Foundation

struct Playlist: Identifiable, Codable, Equatable {
    let id: String
    let platform: Platform
    var name: String
    var songCount: Int
    var lastSyncTime: Date?
    var songs: [Song]

    init(id: String, platform: Platform, name: String, songCount: Int = 0, lastSyncTime: Date? = nil, songs: [Song] = []) {
        self.id = id
        self.platform = platform
        self.name = name
        self.songCount = songCount
        self.lastSyncTime = lastSyncTime
        self.songs = songs
    }

    var isEmpty: Bool { songs.isEmpty }
}
