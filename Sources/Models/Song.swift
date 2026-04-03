import Foundation

struct Song: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let platform: Platform
    var title: String
    var artist: String
    var album: String?
    var duration: Int // seconds
    var playUrl: String?
    var coverUrl: String?

    var formattedDuration: String {
        let min = duration / 60
        let sec = duration % 60
        return String(format: "%d:%02d", min, sec)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(platform)
    }
}
