import Foundation
import SwiftUI
import Combine

final class PassingStore: ObservableObject {
    @Published var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "passing.onboarding.completed") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "passing.onboarding.completed") }
    }
    @Published var selectedTab: AppTab = .home
    @Published var selectedGenres: Set<MusicGenre> = PassingStore.loadGenres() {
        didSet { PassingStore.save(selectedGenres, key: "passing.genres") }
    }
    @Published var todaySong: Song = PassingStore.loadSong() {
        didSet { PassingStore.save(todaySong, key: "passing.todaySong") }
    }
    @Published var memories: [PassingMemory] = PassingStore.loadMemories() {
        didSet { PassingStore.save(memories, key: "passing.memories") }
    }
    @Published var isLocationEnabled = false
    @Published var notificationsEnabled = true
    @Published var sessionSongs: [EncounteredSong] = []
    @Published var sessionPeopleCount = 0
    @Published var sessionStartedAt: Date?
    private var sessionPeerIDs = Set<String>()

    func startPassing() {
        sessionStartedAt = .now
        sessionSongs = []
        sessionPeopleCount = 0
        sessionPeerIDs = []
    }

    func recordEncounter(song: Song, peerID: String, encounteredAt: Date) {
        guard sessionStartedAt != nil, sessionPeerIDs.insert(peerID).inserted else { return }
        sessionPeopleCount += 1
        if !sessionSongs.contains(where: { $0.song.musicItemID == song.musicItemID && $0.song.title == song.title }) {
            sessionSongs.append(EncounteredSong(song: song, encounteredAt: encounteredAt))
        }
    }

    @discardableResult
    func finishPassing(eventName: String, venue: String) -> PassingMemory {
        let memory = PassingMemory(
            eventName: eventName.isEmpty ? "今日のライブ" : eventName,
            venue: venue.isEmpty ? "位置情報なし" : venue,
            date: sessionStartedAt ?? .now,
            peopleCount: sessionPeopleCount,
            songs: sessionSongs
        )
        memories.insert(memory, at: 0)
        sessionStartedAt = nil
        return memory
    }

    func renameMemory(id: UUID, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = memories.firstIndex(where: { $0.id == id }) else { return }
        memories[index].eventName = trimmedName
    }

    private static func loadMemories() -> [PassingMemory] {
        guard let data = UserDefaults.standard.data(forKey: "passing.memories"),
              let memories = try? JSONDecoder().decode([PassingMemory].self, from: data) else {
            return []
        }
        return memories
    }

    private static func loadSong() -> Song {
        guard let data = UserDefaults.standard.data(forKey: "passing.todaySong"),
              let song = try? JSONDecoder().decode(Song.self, from: data) else { return .midnightCity }
        return song
    }

    private static func loadGenres() -> Set<MusicGenre> {
        guard let data = UserDefaults.standard.data(forKey: "passing.genres"),
              let genres = try? JSONDecoder().decode(Set<MusicGenre>.self, from: data) else {
            return [.rock, .jpop]
        }
        return genres
    }

    private static func save<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
