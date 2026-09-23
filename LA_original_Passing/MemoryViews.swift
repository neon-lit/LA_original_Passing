import SwiftUI

struct MemoryListView: View {
    @EnvironmentObject private var store: PassingStore
    @State private var displayMode: MemoryDisplayMode = .list
    @State private var sortOrder: MemorySortOrder = .newest
    @State private var selectedMemory: PassingMemory?
    @State private var displayedMonth = Date.now
    @State private var dayMemorySelection: DayMemorySelection?

    private var sortedMemories: [PassingMemory] {
        switch sortOrder {
        case .newest:
            store.memories.sorted { $0.date > $1.date }
        case .oldest:
            store.memories.sorted { $0.date < $1.date }
        case .mostPeople:
            store.memories.sorted { $0.peopleCount > $1.peopleCount }
        case .mostSongs:
            store.memories.sorted { $0.songs.count > $1.songs.count }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("表示方法", selection: $displayMode) {
                ForEach(MemoryDisplayMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.symbol).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Group {
                if store.memories.isEmpty {
                    ContentUnavailableView(
                        "まだメモリーがありません",
                        systemImage: "sparkles.rectangle.stack",
                        description: Text("PASSINGを終了すると、出会った曲と場所がここに保存されます。")
                    )
                } else if displayMode == .list {
                    List {
                        ForEach(sortedMemories) { memory in
                            Button {
                                selectedMemory = memory
                            } label: {
                                MemoryCard(memory: memory)
                            }
                                .listRowInsets(EdgeInsets(top: 7, leading: 20, bottom: 7, trailing: 20))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                } else {
                    MemoryCalendarView(
                        memories: store.memories,
                        displayedMonth: $displayedMonth,
                        onSelect: selectMemories
                    )
                }
            }
        }
        .navigationTitle("メモリー")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if displayMode == .list, !store.memories.isEmpty {
                    Menu {
                        Picker("表示順", selection: $sortOrder) {
                            ForEach(MemorySortOrder.allCases) { order in
                                Label(order.title, systemImage: order.symbol).tag(order)
                            }
                        }
                    } label: {
                        Label("並び替え", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
        }
        .navigationDestination(item: $selectedMemory) { memory in
            MemoryDetailView(memory: memory)
        }
        .sheet(item: $dayMemorySelection) { selection in
            NavigationStack {
                List(selection.memories) { memory in
                    NavigationLink {
                        MemoryDetailView(memory: memory)
                    } label: {
                        MemoryCard(memory: memory)
                    }
                    .buttonStyle(.plain)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .navigationTitle("この日のメモリー")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") { dayMemorySelection = nil }
                    }
                }
                .passingBackground()
            }
            .presentationDetents([.medium, .large])
        }
        .passingBackground()
    }

    private func selectMemories(_ memories: [PassingMemory]) {
        guard !memories.isEmpty else { return }
        dayMemorySelection = DayMemorySelection(
            memories: memories.sorted { $0.date > $1.date }
        )
    }
}

private struct DayMemorySelection: Identifiable {
    let id = UUID()
    let memories: [PassingMemory]
}

private enum MemoryDisplayMode: String, CaseIterable, Identifiable {
    case list
    case calendar

    var id: String { rawValue }
    var title: String { self == .list ? "一覧" : "カレンダー" }
    var symbol: String { self == .list ? "rectangle.grid.1x2" : "calendar" }
}

private struct MemoryCalendarView: View {
    let memories: [PassingMemory]
    @Binding var displayedMonth: Date
    let onSelect: ([PassingMemory]) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    private var memoriesByDay: [Date: [PassingMemory]] {
        Dictionary(grouping: memories) { calendar.startOfDay(for: $0.date) }
    }

    private var monthDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        let dates = dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
        return Array(repeating: nil, count: leadingEmptyDays) + dates
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let startIndex = max(calendar.firstWeekday - 1, 0)
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Button { moveMonth(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 42, height: 42)
                    }
                    Spacer()
                    Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                        .font(.title2.bold())
                    Spacer()
                    Button { moveMonth(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 42, height: 42)
                    }
                }

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                        Text(symbol)
                            .font(.caption2.bold())
                            .foregroundStyle(index == 0 ? .red.opacity(0.8) : PassingColors.secondaryText)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                        if let date {
                            calendarDay(date)
                        } else {
                            Color.clear.frame(height: 68)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
    }

    private func calendarDay(_ date: Date) -> some View {
        let dayMemories = memoriesByDay[calendar.startOfDay(for: date)] ?? []
        let isToday = calendar.isDateInToday(date)

        return Button {
            onSelect(dayMemories)
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.day()))
                    .font(.caption2.bold())
                    .foregroundStyle(isToday ? .black : .white)
                    .frame(width: 22, height: 18)
                    .background(isToday ? PassingColors.lime : .clear, in: Capsule())

                if let memory = dayMemories.first {
                    ZStack(alignment: .bottomTrailing) {
                        MemoryPlaylistArtwork(memory: memory, size: 43)
                        if dayMemories.count > 1 {
                            Text("+\(dayMemories.count - 1)")
                                .font(.system(size: 9, weight: .black))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(.black.opacity(0.75), in: Circle())
                                .offset(x: 3, y: 3)
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.035))
                        .frame(width: 43, height: 43)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
        }
        .buttonStyle(.plain)
        .disabled(dayMemories.isEmpty)
    }

    private func moveMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            displayedMonth = nextMonth
        }
    }
}

private struct MemoryPlaylistArtwork: View {
    let memory: PassingMemory
    let size: CGFloat

    private var songs: [EncounteredSong] {
        Array(memory.songs.prefix(4))
    }

    var body: some View {
        Group {
            if songs.isEmpty {
                ZStack {
                    LinearGradient(colors: [PassingColors.violet, PassingColors.lime], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note.list")
                        .foregroundStyle(.white)
                }
            } else if songs.count == 1, let item = songs.first {
                CoverArt(song: item.song, size: size)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed((size - 1) / 2), spacing: 1), count: 2),
                    spacing: 1
                ) {
                    ForEach(songs) { item in
                        CoverArt(song: item.song, size: (size - 1) / 2)
                    }
                }
                .frame(width: size, height: size, alignment: .topLeading)
                .background(PassingColors.surface)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.7)
        }
    }
}

private enum MemorySortOrder: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case mostPeople
    case mostSongs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: "新しい順"
        case .oldest: "古い順"
        case .mostPeople: "人数が多い順"
        case .mostSongs: "曲数が多い順"
        }
    }

    var symbol: String {
        switch self {
        case .newest: "calendar.badge.clock"
        case .oldest: "calendar"
        case .mostPeople: "person.2.fill"
        case .mostSongs: "music.note.list"
        }
    }
}

private struct MemoryCard: View {
    let memory: PassingMemory

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(memory.date.formatted(.dateTime.year().month().day()))
                        .font(.caption.bold())
                        .foregroundStyle(PassingColors.lime)
                    Text(memory.eventName).font(.title3.bold()).multilineTextAlignment(.leading)
                    Label(memory.venue, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(PassingColors.secondaryText)
                }
                Spacer()
            }
            HStack(spacing: -12) {
                ForEach(Array(memory.songs.prefix(4))) { item in
                    CoverArt(song: item.song, size: 52)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(PassingColors.background, lineWidth: 3))
                }
                Spacer()
                Text("\(memory.peopleCount)人 / \(memory.songs.count)曲").font(.subheadline.bold())
            }
        }
        .padding(18)
        .background(PassingColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct MemoryDetailView: View {
    let memory: PassingMemory
    @EnvironmentObject private var store: PassingStore
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playlistService = AppleMusicPlaylistService()
    @State private var showPlaylistNameSheet = false
    @State private var showMemoryNameSheet = false
    @State private var showDeleteConfirmation = false
    @State private var playlistName: String
    @State private var memoryName: String
    @State private var hasCreatedPlaylist: Bool

    init(memory: PassingMemory) {
        self.memory = memory
        _playlistName = State(initialValue: AppleMusicPlaylistService.savedName(for: memory.id) ?? memory.eventName)
        _memoryName = State(initialValue: memory.eventName)
        _hasCreatedPlaylist = State(initialValue: AppleMusicPlaylistService.hasPlaylist(for: memory.id))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(memory.date.formatted(.dateTime.year().month().day()))
                        .font(.subheadline.bold())
                        .foregroundStyle(PassingColors.lime)
                    Text(memoryName).font(.system(size: 32, weight: .black, design: .rounded))
                    Label(memory.venue, systemImage: "mappin.and.ellipse").foregroundStyle(PassingColors.secondaryText)
                    Text("\(memory.peopleCount)人の \(memory.songs.count)曲と出会いました")
                        .font(.headline)
                        .padding(.top, 8)
                }
                Button {
                    playlistService.clearError()
                    showPlaylistNameSheet = true
                } label: {
                    Label(
                        hasCreatedPlaylist ? "プレイリスト名・内容を変更" : "Apple Musicにプレイリストを作成",
                        systemImage: hasCreatedPlaylist ? "pencil.and.list.clipboard" : "music.note.list"
                    )
                }
                .buttonStyle(PrimaryButtonStyle())
                Text("出会った曲").font(.title3.bold()).padding(.top, 6)
                LazyVStack(spacing: 10) {
                    ForEach(memory.songs) { item in
                        NavigationLink {
                            SongDetailView(item: item)
                        } label: {
                            SongRow(item: item)
                        }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showMemoryNameSheet = true
                    } label: {
                        Label("メモリー名を変更", systemImage: "pencil")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("メモリーを削除", systemImage: "trash")
                    }
                } label: {
                    Label("メモリーを編集", systemImage: "ellipsis.circle")
                }
            }
        }
        .passingBackground()
        .sheet(isPresented: $showPlaylistNameSheet) {
            playlistNameSheet
                .presentationDetents([.height(390)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMemoryNameSheet) {
            memoryNameSheet
                .presentationDetents([.height(310)])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "このメモリーを削除しますか？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                store.deleteMemories(ids: [memory.id])
                dismiss()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("削除したメモリーは元に戻せません。")
        }
    }

    private var memoryNameSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("メモリー名を変更")
                .font(.title2.bold())
            Text("イベント・ライブ名")
                .font(.caption.bold())
                .foregroundStyle(PassingColors.secondaryText)
            TextField("メモリー名", text: $memoryName)
                .padding(16)
                .background(PassingColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Spacer()
            Button("変更を保存") {
                let trimmedName = memoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                store.renameMemory(id: memory.id, to: trimmedName)
                memoryName = trimmedName
                if !hasCreatedPlaylist {
                    playlistName = trimmedName
                }
                showMemoryNameSheet = false
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(memoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(24)
        .passingBackground()
    }

    private var playlistNameSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(hasCreatedPlaylist ? "プレイリストを変更" : "プレイリストを作成")
                .font(.title2.bold())
            Text("プレイリスト名")
                .font(.caption.bold())
                .foregroundStyle(PassingColors.secondaryText)
            TextField("プレイリスト名", text: $playlistName)
                .textInputAutocapitalization(.never)
                .padding(16)
                .background(PassingColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if let errorMessage = playlistService.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text(hasCreatedPlaylist ? "名前と収録曲をApple Music側にも反映します。" : "初期値はメモリー名です。好きな名前に変更できます。")
                    .font(.caption)
                    .foregroundStyle(PassingColors.secondaryText)
            }

            Spacer()
            Button {
                Task {
                    if await playlistService.createOrUpdatePlaylist(from: memory, named: playlistName) {
                        hasCreatedPlaylist = true
                        showPlaylistNameSheet = false
                        if let musicURL = playlistService.playlistURL ?? URL(string: "music://") {
                            openURL(musicURL)
                        }
                    }
                }
            } label: {
                if playlistService.isCreating {
                    Label(hasCreatedPlaylist ? "変更中" : "作成中", systemImage: "hourglass")
                } else {
                    Label(hasCreatedPlaylist ? "変更を保存" : "この名前で作成", systemImage: "music.note.list")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(playlistService.isCreating || playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(24)
        .passingBackground()
    }
}

private struct SongRow: View {
    let item: EncounteredSong

    var body: some View {
        HStack(spacing: 14) {
            CoverArt(song: item.song, size: 62)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Text(item.song.title)
                        .font(.headline)
                        .lineLimit(1)
                    if item.recommendationCount > 1 {
                        RecommendationCountBadge(count: item.recommendationCount)
                    }
                }
                Text(item.song.artist).font(.subheadline).foregroundStyle(PassingColors.secondaryText)
                if item.recommendationCount > 1 {
                    Text("\(item.recommendationCount)人から届いた曲")
                        .font(.caption.bold())
                        .foregroundStyle(PassingColors.lime)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(PassingColors.secondaryText)
        }
        .padding(10)
        .background(PassingColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 17))
        .overlay {
            if item.recommendationCount > 1 {
                RoundedRectangle(cornerRadius: 17)
                    .stroke(PassingColors.lime.opacity(0.5), lineWidth: 1)
            }
        }
    }
}

struct SongDetailView: View {
    let item: EncounteredSong
    @EnvironmentObject private var previewPlayer: PreviewPlayer
    @Environment(\.openURL) private var openURL
    @State private var isOpeningAppleMusic = false
    @State private var showAppleMusicError = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            CoverArt(song: item.song, size: 280)
            HStack(spacing: 9) {
                Text(item.song.title)
                    .font(.system(size: 31, weight: .black, design: .rounded))
                if item.recommendationCount > 1 {
                    RecommendationCountBadge(count: item.recommendationCount)
                }
            }
                .padding(.top, 34)
            Text(item.song.artist)
                .font(.title3)
                .foregroundStyle(PassingColors.secondaryText)
                .padding(.top, 6)
            Label(item.encounteredAt.formatted(date: .omitted, time: .shortened) + " に出会いました", systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(PassingColors.lime)
                .padding(.top, 18)
            if item.recommendationCount > 1 {
                Label("\(item.recommendationCount)人から届いた曲", systemImage: "person.2.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(PassingColors.secondaryText)
                    .padding(.top, 10)
            }
            Spacer()
            Button { previewPlayer.toggle(song: item.song) } label: {
                PreviewButtonLabel(song: item.song, title: "試聴する")
            }
                .buttonStyle(PrimaryButtonStyle(destructive: true))
                .disabled(item.song.previewURL == nil)
            Button {
                previewPlayer.stop()
                Task {
                    isOpeningAppleMusic = true
                    if let url = await AppleMusicLinkResolver.resolveURL(for: item.song) {
                        openURL(url)
                    } else {
                        showAppleMusicError = true
                    }
                    isOpeningAppleMusic = false
                }
            } label: {
                if isOpeningAppleMusic {
                    Label("Apple Musicを開いています", systemImage: "hourglass")
                } else {
                    Label("Apple Musicで聴く", systemImage: "arrow.up.right")
                }
            }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 10)
                .disabled(isOpeningAppleMusic)
        }
        .padding(22)
        .navigationBarTitleDisplayMode(.inline)
        .passingBackground()
        .onDisappear { previewPlayer.stop() }
        .alert("Apple Musicで開けません", isPresented: $showAppleMusicError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("この曲のApple Musicリンクを取得できませんでした。")
        }
    }
}

private struct RecommendationCountBadge: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.caption.bold().monospacedDigit())
            .foregroundStyle(PassingColors.lime)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(PassingColors.lime.opacity(0.14), in: Capsule())
    }
}
