import Combine
import Foundation
import MusicKit

@MainActor
final class AppleMusicPlaylistService: ObservableObject {
    @Published private(set) var isCreating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var playlistURL: URL?

    static func savedName(for memoryID: UUID) -> String? {
        UserDefaults.standard.string(forKey: nameKey(for: memoryID))
    }

    static func hasPlaylist(for memoryID: UUID) -> Bool {
        UserDefaults.standard.string(forKey: idKey(for: memoryID)) != nil
    }

    static func clearSavedPlaylist(for memoryID: UUID) {
        UserDefaults.standard.removeObject(forKey: idKey(for: memoryID))
        UserDefaults.standard.removeObject(forKey: nameKey(for: memoryID))
    }

    func createOrUpdatePlaylist(from memory: PassingMemory, named playlistName: String) async -> Bool {
        let trimmedName = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "プレイリスト名を入力してください。"
            return false
        }

        isCreating = true
        errorMessage = nil
        playlistURL = nil
        defer { isCreating = false }

        guard await MusicAuthorization.request() == .authorized else {
            errorMessage = "プレイリストを保存するには、Apple Musicへのアクセスを許可してください。"
            return false
        }

        do {
            let songs = try await catalogSongs(for: memory)
            guard !songs.isEmpty else {
                errorMessage = "Apple Musicで見つかる曲がありませんでした。"
                return false
            }

            let playlist: MusicKit.Playlist
            if let existingPlaylist = try await savedPlaylist(for: memory.id) {
                playlist = try await MusicLibrary.shared.edit(
                    existingPlaylist,
                    name: trimmedName,
                    description: "PASSINGで出会った曲",
                    items: songs
                )
            } else {
                playlist = try await MusicLibrary.shared.createPlaylist(
                    name: trimmedName,
                    description: "PASSINGで出会った曲",
                    items: songs
                )
            }

            Self.save(playlistID: playlist.id.rawValue, name: trimmedName, for: memory.id)
            playlistURL = playlist.url
            return true
        } catch {
            errorMessage = "プレイリストを作成・変更できませんでした。Apple Musicの契約状態とライブラリ同期を確認してください。"
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func catalogSongs(for memory: PassingMemory) async throws -> [MusicKit.Song] {
        var itemIDs: [MusicItemID] = []
        for encounteredSong in memory.songs {
            if let itemID = await AppleMusicLinkResolver.resolveMusicItemID(for: encounteredSong.song) {
                let musicItemID = MusicItemID(itemID)
                if !itemIDs.contains(musicItemID) {
                    itemIDs.append(musicItemID)
                }
            }
        }

        guard !itemIDs.isEmpty else { return [] }
        let request = MusicCatalogResourceRequest<MusicKit.Song>(matching: \.id, memberOf: itemIDs)
        return Array(try await request.response().items)
    }

    private func savedPlaylist(for memoryID: UUID) async throws -> MusicKit.Playlist? {
        guard let savedID = UserDefaults.standard.string(forKey: Self.idKey(for: memoryID)) else {
            return nil
        }

        var request = MusicLibraryRequest<MusicKit.Playlist>()
        request.filter(matching: \.id, equalTo: MusicItemID(savedID))
        return try await request.response().items.first
    }

    private static func save(playlistID: String, name: String, for memoryID: UUID) {
        UserDefaults.standard.set(playlistID, forKey: idKey(for: memoryID))
        UserDefaults.standard.set(name, forKey: nameKey(for: memoryID))
    }

    private static func idKey(for memoryID: UUID) -> String {
        "passing.appleMusicPlaylist.id.\(memoryID.uuidString)"
    }

    private static func nameKey(for memoryID: UUID) -> String {
        "passing.appleMusicPlaylist.name.\(memoryID.uuidString)"
    }
}
