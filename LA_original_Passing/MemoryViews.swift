import SwiftUI

struct MemoryListView: View {
    @EnvironmentObject private var store: PassingStore
    @State private var sortOrder: MemorySortOrder = .newest

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
        ScrollView {
            if sortedMemories.isEmpty {
                ContentUnavailableView(
                    "まだメモリーがありません",
                    systemImage: "sparkles.rectangle.stack",
                    description: Text("PASSINGを終了すると、出会った曲と場所がここに保存されます。")
                )
                .padding(.top, 120)
            } else {
                LazyVStack(spacing: 14) {
                    ForEach(sortedMemories) { memory in
                        NavigationLink(value: memory) { MemoryCard(memory: memory) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("メモリー")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
        .navigationDestination(for: PassingMemory.self) { memory in
            MemoryDetailView(memory: memory)
        }
        .passingBackground()
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
                Image(systemName: "chevron.right").foregroundStyle(PassingColors.secondaryText)
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
    @StateObject private var playlistService = AppleMusicPlaylistService()
    @State private var showPlaylistNameSheet = false
    @State private var showMemoryNameSheet = false
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
                        NavigationLink(value: item) { SongRow(item: item) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showMemoryNameSheet = true
                } label: {
                    Label("メモリー名を変更", systemImage: "pencil")
                }
            }
        }
        .navigationDestination(for: EncounteredSong.self) { item in
            SongDetailView(item: item)
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
                Text(item.song.title).font(.headline)
                Text(item.song.artist).font(.subheadline).foregroundStyle(PassingColors.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(PassingColors.secondaryText)
        }
        .padding(10)
        .background(PassingColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 17))
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
            Text(item.song.title)
                .font(.system(size: 31, weight: .black, design: .rounded))
                .padding(.top, 34)
            Text(item.song.artist)
                .font(.title3)
                .foregroundStyle(PassingColors.secondaryText)
                .padding(.top, 6)
            Label(item.encounteredAt.formatted(date: .omitted, time: .shortened) + " に出会いました", systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(PassingColors.lime)
                .padding(.top, 18)
            Spacer()
            Button { previewPlayer.toggle(song: item.song) } label: {
                PreviewButtonLabel(song: item.song, title: "試聴する")
            }
                .buttonStyle(PrimaryButtonStyle(destructive: true))
                .disabled(item.song.previewURL == nil)
            Button {
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
