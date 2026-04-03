import SwiftUI
import Combine

@MainActor
class PlaylistViewModel: ObservableObject {
    static let shared = PlaylistViewModel()

    @Published var playlists: [Playlist] = []
    @Published var selectedPlaylist: Playlist?
    @Published var selectedPlaylistSongs: [Song] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showAddSheet: Bool = false
    @Published var searchText: String = ""

    private let db = DatabaseService.shared
    private let syncService = PlaylistSyncService.shared

    var filteredSongs: [Song] {
        if searchText.isEmpty {
            return selectedPlaylistSongs
        }
        let q = searchText.lowercased()
        return selectedPlaylistSongs.filter {
            $0.title.lowercased().contains(q) ||
            $0.artist.lowercased().contains(q) ||
            ($0.album?.lowercased().contains(q) ?? false)
        }
    }

    private init() {}

    func loadPlaylists() async {
        isLoading = true
        do {
            playlists = try await db.loadPlaylists()
        } catch {
            print("Load playlists error: \(error)")
        }
        isLoading = false
    }

    func selectPlaylist(_ playlist: Playlist) {
        selectedPlaylist = playlist
        selectedPlaylistSongs = playlist.songs
        searchText = ""
    }

    func addPlaylistFromURL(_ urlString: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let playlist = try await syncService.syncPlaylist(from: urlString)
            try await db.savePlaylist(playlist)
            playlists.append(playlist)
            selectedPlaylist = playlist
            selectedPlaylistSongs = playlist.songs
            showAddSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refreshPlaylist(_ playlist: Playlist) async {
        isLoading = true
        errorMessage = nil

        do {
            let platformURL: String
            switch playlist.platform {
            case .qq:
                let pid = playlist.id.replacingOccurrences(of: "qq_", with: "")
                platformURL = "https://y.qq.com/n/ryqq/playlist/\(pid)"
            case .netEase:
                let pid = playlist.id.replacingOccurrences(of: "netease_", with: "")
                platformURL = "https://music.163.com/playlist?id=\(pid)"
            }

            let refreshed = try await syncService.syncPlaylist(from: platformURL)
            var updated = playlist
            updated.songs = refreshed.songs
            updated.lastSyncTime = Date()

            try await db.savePlaylist(updated)

            if let idx = playlists.firstIndex(where: { $0.id == playlist.id }) {
                playlists[idx] = updated
            }
            if selectedPlaylist?.id == playlist.id {
                selectedPlaylistSongs = updated.songs
            }
        } catch {
            errorMessage = "同步失败: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func deletePlaylist(_ playlist: Playlist) async {
        do {
            try await db.deletePlaylist(id: playlist.id)
            playlists.removeAll { $0.id == playlist.id }
            if selectedPlaylist?.id == playlist.id {
                selectedPlaylist = nil
                selectedPlaylistSongs = []
            }
        } catch {
            print("Delete playlist error: \(error)")
        }
    }
}
