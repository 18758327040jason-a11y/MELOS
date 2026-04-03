import Foundation

enum Platform: String, Codable, CaseIterable, Identifiable {
    case qq = "QQ音乐"
    case netEase = "网易云音乐"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .qq: return "music.note"
        case .netEase: return "music.note.list"
        }
    }

    var brandColor: String {
        switch self {
        case .qq: return "#31C34A"
        case .netEase: return "#C20C0C"
        }
    }

    var playlistURLPattern: String {
        switch self {
        case .qq: return "y.qq.com/n/ryqq/playlist/"
        case .netEase: return "music.163.com/playlist"
        }
    }

    var playlistIDFromURL: (String) -> String? {
        return { url in
            switch self {
            case .qq:
                if let range = url.range(of: "playlist/([a-zA-Z0-9]+)", options: .regularExpression) {
                    return String(url[range]).replacingOccurrences(of: "playlist/", with: "")
                }
            case .netEase:
                if let urlObj = URL(string: url),
                   let components = URLComponents(url: urlObj, resolvingAgainstBaseURL: false),
                   let idItem = components.queryItems?.first(where: { $0.name == "id" }) {
                    return idItem.value
                }
                if let range = url.range(of: "id=(\\d+)", options: .regularExpression) {
                    return String(url[range]).replacingOccurrences(of: "id=", with: "")
                }
            }
            return nil
        }
    }
}
