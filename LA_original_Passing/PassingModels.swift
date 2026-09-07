import Foundation
import SwiftUI

struct Song: Identifiable, Hashable {
    let id: UUID
    let title: String
    let artist: String
    let colors: [Color]
    let symbol: String

    init(id: UUID = UUID(), title: String, artist: String, colors: [Color], symbol: String = "waveform") {
        self.id = id
        self.title = title
        self.artist = artist
        self.colors = colors
        self.symbol = symbol
    }
}

struct EncounteredSong: Identifiable, Hashable {
    let id: UUID
    let song: Song
    let encounteredAt: Date

    init(id: UUID = UUID(), song: Song, encounteredAt: Date) {
        self.id = id
        self.song = song
        self.encounteredAt = encounteredAt
    }
}

struct PassingMemory: Identifiable, Hashable {
    let id: UUID
    var eventName: String
    let venue: String
    let date: Date
    let peopleCount: Int
    let songs: [EncounteredSong]

    init(id: UUID = UUID(), eventName: String, venue: String, date: Date, peopleCount: Int, songs: [EncounteredSong]) {
        self.id = id
        self.eventName = eventName
        self.venue = venue
        self.date = date
        self.peopleCount = peopleCount
        self.songs = songs
    }
}

enum MusicGenre: String, CaseIterable, Identifiable {
    case rock = "ロック"
    case jpop = "J-POP"
    case hiphop = "HIPHOP"
    case kpop = "K-POP"
    case japaneseRock = "邦ロック"
    case electronic = "エレクトロニック"
    case alternative = "オルタナティブ"
    case rnb = "R&B"

    var id: String { rawValue }
}

extension Song {
    static let midnightCity = Song(title: "Midnight City", artist: "M83", colors: [.indigo, .pink], symbol: "sparkles")

    static let samples: [Song] = [
        midnightCity,
        Song(title: "怪獣", artist: "サカナクション", colors: [.blue, .cyan], symbol: "water.waves"),
        Song(title: "NIGHT DANCER", artist: "imase", colors: [.purple, .orange], symbol: "moon.stars.fill"),
        Song(title: "New Jeans", artist: "NewJeans", colors: [.pink, .mint], symbol: "heart.fill"),
        Song(title: "飛行艇", artist: "King Gnu", colors: [.orange, .red], symbol: "airplane"),
        Song(title: "踊り子", artist: "Vaundy", colors: [.green, .yellow], symbol: "figure.dance"),
        Song(title: "Blinding Lights", artist: "The Weeknd", colors: [.red, .purple], symbol: "sun.max.fill"),
        Song(title: "Super Shy", artist: "NewJeans", colors: [.cyan, .blue], symbol: "cloud.fill"),
        Song(title: "Teenager Forever", artist: "King Gnu", colors: [.yellow, .orange], symbol: "bolt.fill")
    ]
}

extension PassingMemory {
    static let sampleMemories: [PassingMemory] = [
        PassingMemory(
            eventName: "SUMMER SONIC 2026",
            venue: "ZOZOマリンスタジアム",
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 15)) ?? .now,
            peopleCount: 32,
            songs: Array(Song.samples.prefix(6)).enumerated().map { index, song in
                EncounteredSong(song: song, encounteredAt: Calendar.current.date(byAdding: .minute, value: index * 18, to: Date.now) ?? .now)
            }
        ),
        PassingMemory(
            eventName: "GREENROOM FESTIVAL",
            venue: "横浜赤レンガ倉庫",
            date: Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 24)) ?? .now,
            peopleCount: 18,
            songs: Array(Song.samples.suffix(4)).enumerated().map { index, song in
                EncounteredSong(song: song, encounteredAt: Calendar.current.date(byAdding: .minute, value: index * 12, to: Date.now) ?? .now)
            }
        )
    ]
}
