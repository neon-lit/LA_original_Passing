import AVFoundation
import Combine
import MusicKit
import SwiftUI

@MainActor
final class AppleMusicSearchService: ObservableObject {
    @Published private(set) var results: [Song] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var authorizationStatus = MusicAuthorization.currentStatus

    func requestAuthorization() async -> Bool {
        authorizationStatus = await MusicAuthorization.request()
        return authorizationStatus == .authorized
    }

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
            var components = URLComponents(string: "https://itunes.apple.com/search")
            components?.queryItems = [
                URLQueryItem(name: "term", value: trimmedTerm),
                URLQueryItem(name: "country", value: "JP"),
                URLQueryItem(name: "media", value: "music"),
                URLQueryItem(name: "entity", value: "song"),
                URLQueryItem(name: "limit", value: "25")
            ]
            guard let url = components?.url else { throw URLError(.badURL) }
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                throw URLError(.badServerResponse)
            }
            let searchResponse = try JSONDecoder().decode(AppleMusicSearchResponse.self, from: data)
            results = searchResponse.results.map(Song.init(searchResult:))
            if results.isEmpty {
                errorMessage = "曲が見つかりませんでした。"
            }
        } catch {
            results = []
            errorMessage = "Apple Musicを検索できませんでした。通信環境とMusicKit設定を確認してください。"
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
            return exactMatch?.trackViewURL ?? searchResponse.results.first?.trackViewURL
        } catch {
            return nil
        }
    }
}

@MainActor
final class PreviewPlayer: ObservableObject {
    @Published private(set) var playingSongID: UUID?
    @Published private(set) var loadingSongID: UUID?
    @Published private(set) var errorMessage: String?
    private var player: AVPlayer?

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

            let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            player.volume = 1
            player.automaticallyWaitsToMinimizeStalling = true
            self.player = player
            loadingSongID = nil
            playingSongID = song.id
            player.play()
        } catch {
            loadingSongID = nil
            playingSongID = nil
            errorMessage = "この曲の試聴音源を再生できませんでした。別の曲でもう一度お試しください。"
        }
    }
}

private enum PreviewPlaybackError: Error {
    case unplayable
}

private extension Song {
    init(searchResult: AppleMusicSearchResult) {
        let largeArtworkURL = searchResult.artworkURL.flatMap {
            URL(string: $0.absoluteString.replacingOccurrences(of: "100x100", with: "600x600"))
        }
        self.init(
            title: searchResult.trackName,
            artist: searchResult.artistName,
            colors: [.indigo, .purple],
            symbol: "music.note",
            musicItemID: String(searchResult.trackID),
            artworkURL: largeArtworkURL,
            previewURL: searchResult.previewURL,
            appleMusicURL: searchResult.trackViewURL
        )
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
