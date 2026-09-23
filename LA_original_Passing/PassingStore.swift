import Foundation
import SwiftUI
import Combine

enum EncounterRecordingResult {
    case newSong
    case duplicate(song: Song, count: Int)
}

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

    @discardableResult
    func recordEncounter(song: Song, peerID: String, encounteredAt: Date) -> EncounterRecordingResult? {
        guard sessionStartedAt != nil, sessionPeerIDs.insert(peerID).inserted else { return nil }
        sessionPeopleCount += 1
        if let index = sessionSongs.firstIndex(where: { $0.song.representsSameTrack(as: song) }) {
            sessionSongs[index].recommendationCount += 1
            return .duplicate(song: sessionSongs[index].song, count: sessionSongs[index].recommendationCount)
        } else {
            sessionSongs.append(EncounteredSong(song: song, encounteredAt: encounteredAt))
            return .newSong
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

    func deleteMemories(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        memories.removeAll { memory in
            guard ids.contains(memory.id) else { return false }
            AppleMusicPlaylistService.clearSavedPlaylist(for: memory.id)
            return true
        }
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

private extension Song {
    func representsSameTrack(as other: Song) -> Bool {
        if let musicItemID, let otherMusicItemID = other.musicItemID {
            return musicItemID == otherMusicItemID
        }

        return title.compare(other.title, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            && artist.compare(other.artist, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}
