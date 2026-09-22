#if DEBUG
import Combine
import SwiftUI
import UIKit

@MainActor
enum MarketingCapture {
    static let isActive = ProcessInfo.processInfo.arguments.contains("-MarketingCapture")
    static var showFinishSheetOnAppear = false

    static let summerSonic: PassingMemory = {
        let calendar = Calendar(identifier: .gregorian)
        let eventDate = calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 7,
            hour: 18,
            minute: 20
        )) ?? .now

        let songs = marketingSongs.enumerated().map { index, song in
            EncounteredSong(
                song: song,
                encounteredAt: calendar.date(byAdding: .minute, value: index * 7, to: eventDate) ?? eventDate
            )
        }

        return PassingMemory(
            eventName: "SUMMER SONIC 2026",
            venue: "ZOZOマリンスタジアム",
            date: eventDate,
            peopleCount: 32,
            songs: songs
        )
    }()

    static let marketingSongs: [Song] = [
        Song(title: "Midnight City", artist: "M83", colors: [.indigo, .pink], symbol: "sparkles"),
        Song(title: "怪獣", artist: "サカナクション", colors: [.blue, .cyan], symbol: "water.waves"),
        Song(title: "NIGHT DANCER", artist: "imase", colors: [.purple, .orange], symbol: "moon.stars.fill"),
        Song(title: "飛行艇", artist: "King Gnu", colors: [.orange, .red], symbol: "airplane"),
        Song(title: "踊り子", artist: "Vaundy", colors: [.green, .yellow], symbol: "figure.dance"),
        Song(title: "Blinding Lights", artist: "The Weeknd", colors: [.red, .purple], symbol: "sun.max.fill"),
        Song(title: "Super Shy", artist: "NewJeans", colors: [.cyan, .blue], symbol: "cloud.fill"),
        Song(title: "Teenager Forever", artist: "King Gnu", colors: [.yellow, .orange], symbol: "bolt.fill"),
        Song(title: "アイドル", artist: "YOASOBI", colors: [.pink, .purple], symbol: "star.fill"),
        Song(title: "水平線", artist: "back number", colors: [.blue, .indigo], symbol: "water.waves"),
        Song(title: "Lemon", artist: "米津玄師", colors: [.yellow, .green], symbol: "leaf.fill"),
        Song(title: "青のすみか", artist: "キタニタツヤ", colors: [.cyan, .indigo], symbol: "circle.hexagongrid.fill"),
        Song(title: "群青", artist: "YOASOBI", colors: [.indigo, .blue], symbol: "paintpalette.fill"),
        Song(title: "白日", artist: "King Gnu", colors: [.gray, .blue], symbol: "cloud.sun.fill"),
        Song(title: "不可幸力", artist: "Vaundy", colors: [.purple, .blue], symbol: "waveform.path"),
        Song(title: "新宝島", artist: "サカナクション", colors: [.teal, .green], symbol: "sailboat.fill"),
        Song(title: "Pretender", artist: "Official髭男dism", colors: [.orange, .pink], symbol: "heart.circle.fill"),
        Song(title: "Dynamite", artist: "BTS", colors: [.yellow, .pink], symbol: "burst.fill"),
        Song(title: "Ditto", artist: "NewJeans", colors: [.mint, .blue], symbol: "snowflake"),
        Song(title: "Seven", artist: "Jung Kook", colors: [.purple, .pink], symbol: "7.circle.fill"),
        Song(title: "Levitating", artist: "Dua Lipa", colors: [.indigo, .cyan], symbol: "moon.fill"),
        Song(title: "As It Was", artist: "Harry Styles", colors: [.orange, .yellow], symbol: "sun.horizon.fill"),
        Song(title: "bad guy", artist: "Billie Eilish", colors: [.green, .black], symbol: "bolt.circle.fill"),
        Song(title: "Sunflower", artist: "Post Malone, Swae Lee", colors: [.yellow, .orange], symbol: "sun.max.circle.fill")
    ]

    static func seed(_ store: PassingStore) {
        store.hasCompletedOnboarding = true
        store.selectedGenres = [.rock, .jpop, .alternative]
        store.todaySong = marketingSongs[0]
        store.memories = [summerSonic] + PassingMemory.sampleMemories.dropFirst()
        store.sessionStartedAt = Calendar.current.date(byAdding: .minute, value: -84, to: .now)
        store.sessionPeopleCount = summerSonic.peopleCount
        store.sessionSongs = summerSonic.songs
    }

    static func snapshotKeyWindow() -> UIImage? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    static func writePNG(_ image: UIImage, name: String) {
        guard let data = image.pngData() else { return }
        let directory = outputDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent("\(name).png"), options: .atomic)
    }

    static func markComplete() {
        let directory = outputDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? Data("complete\n".utf8).write(
            to: directory.appendingPathComponent("capture-complete.txt"),
            options: .atomic
        )
    }

    private static var outputDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("marketing", isDirectory: true)
            .appendingPathComponent("ja", isDirectory: true)
    }
}

@MainActor
private final class MarketingCaptureNavigation: ObservableObject {
    enum Route: Hashable {
        case home
        case passing
        case summary
        case memories
        case eventSongs
        case songDetail
    }

    @Published var route: Route = .home
}

struct MarketingCaptureHost: View {
    @EnvironmentObject private var store: PassingStore
    @StateObject private var navigation = MarketingCaptureNavigation()
    @State private var didStart = false

    var body: some View {
        Group {
            switch navigation.route {
            case .home, .memories:
                MainTabView()
            case .passing, .summary:
                NavigationStack { PassingSessionView() }
            case .eventSongs:
                NavigationStack { MemoryDetailView(memory: MarketingCapture.summerSonic) }
            case .songDetail:
                NavigationStack {
                    SongDetailView(item: MarketingCapture.summerSonic.songs[1])
                }
            }
        }
        .id(navigation.route)
        .onAppear {
            guard !didStart else { return }
            didStart = true
            Task {
                MarketingCapture.seed(store)
                await MarketingCaptureCoordinator(
                    navigation: navigation,
                    store: store
                ).run()
            }
        }
    }
}

@MainActor
private struct MarketingCaptureCoordinator {
    let navigation: MarketingCaptureNavigation
    let store: PassingStore

    func run() async {
        let steps: [(String, MarketingCaptureNavigation.Route)] = [
            ("01-home", .home),
            ("02-passing", .passing),
            ("03-summary", .summary),
            ("04-memories", .memories),
            ("05-event-songs", .eventSongs),
            ("06-song-detail", .songDetail)
        ]

        for (name, route) in steps {
            MarketingCapture.showFinishSheetOnAppear = route == .summary
            store.selectedTab = route == .memories ? .memory : .home
            navigation.route = route
            try? await Task.sleep(for: .milliseconds(route == .summary ? 2_400 : 1_800))
            if let image = MarketingCapture.snapshotKeyWindow() {
                MarketingCapture.writePNG(image, name: name)
            }
            try? await Task.sleep(for: .milliseconds(500))
        }

        MarketingCapture.showFinishSheetOnAppear = false
        MarketingCapture.markComplete()
    }
}
#endif
