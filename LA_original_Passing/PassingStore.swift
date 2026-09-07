import Foundation
import SwiftUI
import Combine

final class PassingStore: ObservableObject {
    @Published var hasCompletedOnboarding = false
    @Published var selectedGenres: Set<MusicGenre> = [.rock, .jpop]
    @Published var todaySong: Song = .midnightCity
    @Published var memories: [PassingMemory] = PassingMemory.sampleMemories
    @Published var isMusicConnected = false
    @Published var isLocationEnabled = false
    @Published var notificationsEnabled = true
    @Published var sessionSongs: [EncounteredSong] = []
    @Published var sessionPeopleCount = 0
    @Published var sessionStartedAt: Date?

    func startPassing() {
        sessionStartedAt = .now
        sessionSongs = []
        sessionPeopleCount = 0
    }

    func discoverSong() {
        let usedIDs = Set(sessionSongs.map(\.song.id))
        let availableSongs = Song.samples.filter { $0.id != todaySong.id && !usedIDs.contains($0.id) }
        guard let song = availableSongs.randomElement() else { return }
        sessionSongs.append(EncounteredSong(song: song, encounteredAt: .now))
        sessionPeopleCount += Int.random(in: 1...3)
    }

    @discardableResult
    func finishPassing(eventName: String) -> PassingMemory {
        if sessionSongs.isEmpty {
            discoverSong()
            discoverSong()
        }
        let memory = PassingMemory(
            eventName: eventName.isEmpty ? "今日のライブ" : eventName,
            venue: "現在地付近",
            date: sessionStartedAt ?? .now,
            peopleCount: max(sessionPeopleCount, sessionSongs.count),
            songs: sessionSongs
        )
        memories.insert(memory, at: 0)
        sessionStartedAt = nil
        return memory
    }
}
