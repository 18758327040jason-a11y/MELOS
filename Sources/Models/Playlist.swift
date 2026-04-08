import Foundation

struct Playlist: Identifiable, Equatable {
    let id: String
    let platform: Platform
    var name: String
    var songCount: Int { songs.count }
    var lastSyncTime: Date?
    var songs: [Song]
    var coverUrl: String?

    init(id: String, platform: Platform, name: String, lastSyncTime: Date? = nil, songs: [Song] = [], coverUrl: String? = nil) {
        self.id = id
        self.platform = platform
        self.name = name
        self.lastSyncTime = lastSyncTime
        self.songs = songs
        self.coverUrl = coverUrl
    }

    var isEmpty: Bool { songs.isEmpty }
}
