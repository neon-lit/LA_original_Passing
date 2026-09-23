import AVFoundation
import Combine
import SwiftUI

@MainActor
final class AppleMusicSearchService: ObservableObject {
    @Published private(set) var results: [Song] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?

    func search(for term: String) async {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTerm.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let searchResponse = try await fetch(term: trimmedTerm, limit: 25)
            results = searchResponse.results.map(Song.init(searchResult:))
            if results.isEmpty {
                errorMessage = "曲が見つかりませんでした。"
            }
        } catch {
            results = []
            errorMessage = "Apple Musicを検索できませんでした。通信環境とMusicKit設定を確認してください。"
        }
    }

    func loadRecommendations(for genres: Set<MusicGenre>) async {
        guard !genres.isEmpty else {
            results = []
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            var recommendations: [AppleMusicSearchResult] = []
            var usedTrackIDs = Set<Int>()

            for genre in genres.sorted(by: { $0.rawValue < $1.rawValue }).prefix(4) {
                let response = try await fetch(term: genre.searchTerm, limit: 8)
                for result in response.results where usedTrackIDs.insert(result.trackID).inserted {
                    recommendations.append(result)
                }
            }

            results = recommendations.prefix(24).map(Song.init(searchResult:))
            if results.isEmpty {
                errorMessage = "選択したジャンルの候補が見つかりませんでした。"
            }
        } catch {
            results = []
            errorMessage = "おすすめを取得できませんでした。通信環境を確認してください。"
        }
    }

    private func fetch(term: String, limit: Int) async throws -> AppleMusicSearchResponse {
        var components = URLComponents(string: "https://itunes.apple.com/search")
        components?.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "country", value: "JP"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        guard let url = components?.url else { throw URLError(.badURL) }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AppleMusicSearchResponse.self, from: data)
    }
}

private extension MusicGenre {
    var searchTerm: String {
        switch self {
        case .rock: "ロック 人気"
        case .jpop: "J-POP 人気"
        case .hiphop: "ヒップホップ 人気"
        case .kpop: "K-POP 人気"
        case .japaneseRock: "邦ロック 人気"
        case .electronic: "エレクトロニック 人気"
        case .alternative: "オルタナティブ 人気"
        case .rnb: "R&B 人気"
        }
    }
}

private struct AppleMusicSearchResponse: Decodable {
    let results: [AppleMusicSearchResult]
}

private struct AppleMusicSearchResult: Decodable {
    let trackID: Int
    let trackName: String
    let artistName: String
    let artworkURL: URL?
    let previewURL: URL?
    let trackViewURL: URL?

    enum CodingKeys: String, CodingKey {
        case trackID = "trackId"
        case trackName
        case artistName
        case artworkURL = "artworkUrl100"
        case previewURL = "previewUrl"
        case trackViewURL = "trackViewUrl"
    }
}

enum AppleMusicLinkResolver {
    static func resolveURL(for song: Song) async -> URL? {
        if let appleMusicURL = song.appleMusicURL {
            return appleMusicURL
        }

        return await searchResult(for: song)?.trackViewURL
    }

    static func resolveMusicItemID(for song: Song) async -> String? {
        if let musicItemID = song.musicItemID {
            return musicItemID
        }

        return await searchResult(for: song).map { String($0.trackID) }
    }

    static func resolveArtworkURL(for song: Song, refresh: Bool = false) async -> URL? {
        if !refresh, let artworkURL = song.artworkURL {
            return artworkURL
        }

        return await searchResult(for: song)?.largeArtworkURL
    }

    private static func searchResult(for song: Song) async -> AppleMusicSearchResult? {
        do {
            var components = URLComponents(string: "https://itunes.apple.com/search")
            components?.queryItems = [
                URLQueryItem(name: "term", value: "\(song.title) \(song.artist)"),
                URLQueryItem(name: "country", value: "JP"),
                URLQueryItem(name: "media", value: "music"),
                URLQueryItem(name: "entity", value: "song"),
                URLQueryItem(name: "limit", value: "10")
            ]
            guard let url = components?.url else { return nil }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else { return nil }

            let searchResponse = try JSONDecoder().decode(AppleMusicSearchResponse.self, from: data)
            let exactMatch = searchResponse.results.first {
                $0.trackName.localizedCaseInsensitiveCompare(song.title) == .orderedSame &&
                $0.artistName.localizedCaseInsensitiveCompare(song.artist) == .orderedSame
            }
            return exactMatch ?? searchResponse.results.first
        } catch {
            return nil
        }
    }
}

@MainActor
final class PreviewPlayer: NSObject, ObservableObject {
    @Published private(set) var playingSongID: UUID?
    @Published private(set) var loadingSongID: UUID?
    @Published private(set) var errorMessage: String?
    private var player: AVPlayer?
    private weak var observedPlayerItem: AVPlayerItem?

    func toggle(song: Song) {
        guard let previewURL = song.previewURL else { return }
        if playingSongID == song.id {
            stop()
            return
        }

        Task { await play(song: song, url: previewURL) }
    }

    func clearError() {
        errorMessage = nil
    }

    func stop() {
        if let observedPlayerItem {
            NotificationCenter.default.removeObserver(
                self,
                name: .AVPlayerItemDidPlayToEndTime,
                object: observedPlayerItem
            )
            self.observedPlayerItem = nil
        }
        player?.pause()
        player = nil
        playingSongID = nil
        loadingSongID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func play(song: Song, url: URL) async {
        stop()
        loadingSongID = song.id
        errorMessage = nil

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)

            let asset = AVURLAsset(url: url)
            guard try await asset.load(.isPlayable) else {
                throw PreviewPlaybackError.unplayable
            }

            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            player.volume = 1
            player.automaticallyWaitsToMinimizeStalling = true
            self.player = player
            observedPlayerItem = playerItem
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playbackDidFinish),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem,
            )
            loadingSongID = nil
            playingSongID = song.id
            player.play()
        } catch {
            loadingSongID = nil
            playingSongID = nil
            errorMessage = "この曲の試聴音源を再生できませんでした。別の曲でもう一度お試しください。"
        }
    }

    @objc nonisolated private func playbackDidFinish() {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }
}

private enum PreviewPlaybackError: Error {
    case unplayable
}

private extension Song {
    init(searchResult: AppleMusicSearchResult) {
        self.init(
            title: searchResult.trackName,
            artist: searchResult.artistName,
            colors: [.indigo, .purple],
            symbol: "music.note",
            musicItemID: String(searchResult.trackID),
            artworkURL: searchResult.largeArtworkURL,
            previewURL: searchResult.previewURL,
            appleMusicURL: searchResult.trackViewURL
        )
    }
}

private extension AppleMusicSearchResult {
    var largeArtworkURL: URL? {
        artworkURL.flatMap {
            URL(string: $0.absoluteString.replacingOccurrences(of: "100x100", with: "600x600"))
        }
    }
}

struct PreviewButtonLabel: View {
    @EnvironmentObject private var previewPlayer: PreviewPlayer
    let song: Song
    var title = "試聴"

    var body: some View {
        if previewPlayer.loadingSongID == song.id {
            Label("読み込み中", systemImage: "hourglass")
        } else {
            Label(
                previewPlayer.playingSongID == song.id ? "停止" : title,
                systemImage: previewPlayer.playingSongID == song.id ? "pause.fill" : "play.fill"
            )
        }
    }
}
