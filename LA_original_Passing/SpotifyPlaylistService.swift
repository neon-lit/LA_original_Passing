@preconcurrency import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import Security
import UIKit

@MainActor
final class SpotifyPlaylistService: NSObject, ObservableObject {
    @Published private(set) var isCreating = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var playlistURL: URL?

    private var authenticationSession: ASWebAuthenticationSession?

    func createPlaylist(from memory: PassingMemory, named playlistName: String) async -> Bool {
        let trimmedName = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "プレイリスト名を入力してください。"
            return false
        }

        isCreating = true
        errorMessage = nil
        playlistURL = nil
        defer { isCreating = false }

        do {
            let accessToken = try await validAccessToken()
            let trackURIs = try await spotifyTrackURIs(for: memory.songs, accessToken: accessToken)
            guard !trackURIs.isEmpty else {
                errorMessage = "Spotifyで見つかる曲がありませんでした。"
                return false
            }

            let playlist = try await createEmptyPlaylist(
                named: trimmedName,
                accessToken: accessToken
            )
            try await addTracks(trackURIs, to: playlist.id, accessToken: accessToken)
            playlistURL = URL(string: "spotify:playlist:\(playlist.id)") ?? playlist.externalURLs.spotify
            return true
        } catch SpotifyError.configuration {
            errorMessage = "Spotify Client IDが未設定です。リリース設定を確認してください。"
        } catch SpotifyError.cancelled {
            errorMessage = "Spotifyとの連携がキャンセルされました。"
        } catch SpotifyError.authorization {
            SpotifyTokenStore.clear()
            errorMessage = "Spotifyへログインできませんでした。もう一度お試しください。"
        } catch let SpotifyError.request(statusCode, message) {
            let status = statusCode.map { " (\($0))" } ?? ""
            errorMessage = "Spotifyでプレイリストを作成できませんでした\(status)。\(message ?? "もう一度お試しください。")"
        } catch {
            errorMessage = "Spotifyプレイリストを作成できませんでした。通信環境を確認してください。"
        }
        return false
    }

    func clearError() {
        errorMessage = nil
    }

    private func validAccessToken() async throws -> String {
        if let token = SpotifyTokenStore.load() {
            if token.expiresAt.timeIntervalSinceNow > 60 {
                return token.accessToken
            }
            if let refreshToken = token.refreshToken {
                do {
                    let refreshedToken = try await requestToken(
                        parameters: [
                            "client_id": try clientID(),
                            "grant_type": "refresh_token",
                            "refresh_token": refreshToken
                        ],
                        existingRefreshToken: refreshToken
                    )
                    SpotifyTokenStore.save(refreshedToken)
                    return refreshedToken.accessToken
                } catch {
                    SpotifyTokenStore.clear()
                }
            }
        }

        let token = try await authorize()
        SpotifyTokenStore.save(token)
        return token.accessToken
    }

    private func authorize() async throws -> SpotifyToken {
        let clientID = try clientID()
        let redirectURI = try redirectURI()
        let verifier = randomURLSafeString(byteCount: 64)
        let challenge = Self.base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
        let state = randomURLSafeString(byteCount: 24)

        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "playlist-modify-private playlist-modify-public"),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "show_dialog", value: "true")
        ]
        guard let authorizationURL = components?.url,
              let callbackScheme = URL(string: redirectURI)?.scheme else {
            throw SpotifyError.configuration
        }

        defer { authenticationSession = nil }
        let callbackURL: URL = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let authenticationError = error as? ASWebAuthenticationSessionError,
                   authenticationError.code == .canceledLogin {
                    continuation.resume(throwing: SpotifyError.cancelled)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: SpotifyError.authorization)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authenticationSession = session
            if !session.start() {
                continuation.resume(throwing: SpotifyError.authorization)
            }
        }
        guard let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              callbackComponents.queryItems?.first(where: { $0.name == "state" })?.value == state,
              callbackComponents.queryItems?.first(where: { $0.name == "error" }) == nil,
              let code = callbackComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw SpotifyError.authorization
        }

        return try await requestToken(parameters: [
            "client_id": clientID,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier
        ])
    }

    private func requestToken(
        parameters: [String: String],
        existingRefreshToken: String? = nil
    ) async throws -> SpotifyToken {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            throw SpotifyError.authorization
        }
        var formComponents = URLComponents()
        formComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formComponents.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw SpotifyError.authorization
        }

        let responseToken = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        return SpotifyToken(
            accessToken: responseToken.accessToken,
            refreshToken: responseToken.refreshToken ?? existingRefreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(responseToken.expiresIn))
        )
    }

    private func spotifyTrackURIs(
        for encounteredSongs: [EncounteredSong],
        accessToken: String
    ) async throws -> [String] {
        var uris: [String] = []
        for item in encounteredSongs {
            guard let uri = try await searchTrack(item.song, accessToken: accessToken),
                  !uris.contains(uri) else { continue }
            uris.append(uri)
        }
        return uris
    }

    private func searchTrack(_ song: Song, accessToken: String) async throws -> String? {
        var components = URLComponents(string: "https://api.spotify.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "track:\(song.title) artist:\(song.artist)"),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "market", value: "JP"),
            URLQueryItem(name: "limit", value: "5")
        ]
        guard let url = components?.url else { return nil }
        let data = try await spotifyRequest(url: url, method: "GET", accessToken: accessToken)
        let response = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
        let exactMatch = response.tracks.items.first { track in
            track.name.localizedCaseInsensitiveCompare(song.title) == .orderedSame
                && track.artists.contains { artist in
                    artist.name.localizedCaseInsensitiveCompare(song.artist) == .orderedSame
                }
        }
        return (exactMatch ?? response.tracks.items.first)?.uri
    }

    private func createEmptyPlaylist(named name: String, accessToken: String) async throws -> SpotifyPlaylistResponse {
        guard let url = URL(string: "https://api.spotify.com/v1/me/playlists") else {
            throw SpotifyError.request(statusCode: nil, message: nil)
        }
        let body = try JSONEncoder().encode(
            SpotifyCreatePlaylistRequest(
                name: name,
                description: "PASSINGで出会った曲",
                isPublic: false
            )
        )
        let data = try await spotifyRequest(url: url, method: "POST", accessToken: accessToken, body: body)
        return try JSONDecoder().decode(SpotifyPlaylistResponse.self, from: data)
    }

    private func addTracks(_ uris: [String], to playlistID: String, accessToken: String) async throws {
        guard let url = URL(string: "https://api.spotify.com/v1/playlists/\(playlistID)/items") else {
            throw SpotifyError.request(statusCode: nil, message: nil)
        }
        for startIndex in stride(from: 0, to: uris.count, by: 100) {
            let endIndex = min(startIndex + 100, uris.count)
            let body = try JSONEncoder().encode(SpotifyAddTracksRequest(uris: Array(uris[startIndex..<endIndex])))
            _ = try await spotifyRequest(url: url, method: "POST", accessToken: accessToken, body: body)
        }
    }

    private func spotifyRequest(
        url: URL,
        method: String,
        accessToken: String,
        body: Data? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.request(statusCode: nil, message: nil)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            let apiError = try? JSONDecoder().decode(SpotifyAPIErrorResponse.self, from: data)
            throw SpotifyError.request(
                statusCode: httpResponse.statusCode,
                message: apiError?.error.message
            )
        }
        return data
    }

    private func clientID() throws -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SpotifyClientID") as? String,
              !value.isEmpty,
              !value.contains("$(") else {
            throw SpotifyError.configuration
        }
        return value
    }

    private func redirectURI() throws -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SpotifyRedirectURI") as? String,
              let url = URL(string: value),
              url.scheme != nil else {
            throw SpotifyError.configuration
        }
        return value
    }

    private func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Self.base64URL(Data(bytes))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension SpotifyPlaylistService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = windowScenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        guard let windowScene = windowScenes.first else {
            preconditionFailure("Spotify authentication requires an active window scene.")
        }
        return UIWindow(windowScene: windowScene)
    }
}

private struct SpotifyToken: Codable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

private struct SpotifyTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct SpotifySearchResponse: Decodable {
    let tracks: SpotifyTracks
}

private struct SpotifyTracks: Decodable {
    let items: [SpotifyTrack]
}

private struct SpotifyTrack: Decodable {
    let name: String
    let uri: String
    let artists: [SpotifyArtist]
}

private struct SpotifyArtist: Decodable {
    let name: String
}

private struct SpotifyCreatePlaylistRequest: Encodable {
    let name: String
    let description: String
    let isPublic: Bool

    enum CodingKeys: String, CodingKey {
        case name, description
        case isPublic = "public"
    }
}

private struct SpotifyPlaylistResponse: Decodable {
    let id: String
    let externalURLs: SpotifyExternalURLs

    enum CodingKeys: String, CodingKey {
        case id
        case externalURLs = "external_urls"
    }
}

private struct SpotifyExternalURLs: Decodable {
    let spotify: URL
}

private struct SpotifyAddTracksRequest: Encodable {
    let uris: [String]
}

private struct SpotifyAPIErrorResponse: Decodable {
    let error: SpotifyAPIErrorBody
}

private struct SpotifyAPIErrorBody: Decodable {
    let message: String
}

private enum SpotifyError: Error {
    case configuration
    case cancelled
    case authorization
    case request(statusCode: Int?, message: String?)
}

private enum SpotifyTokenStore {
    private static let account = "spotify-oauth-token-v2"
    private static var service: String {
        "\(Bundle.main.bundleIdentifier ?? "PASSING").spotify"
    }

    static func save(_ token: SpotifyToken) {
        guard let data = try? JSONEncoder().encode(token) else { return }
        clear()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> SpotifyToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(SpotifyToken.self, from: data)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
