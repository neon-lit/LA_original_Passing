import SwiftUI

struct MemoryListView: View {
    @EnvironmentObject private var store: PassingStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(store.memories) { memory in
                    NavigationLink(value: memory) { MemoryCard(memory: memory) }
                        .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .navigationTitle("メモリー")
        .navigationDestination(for: PassingMemory.self) { memory in
            MemoryDetailView(memory: memory)
        }
        .passingBackground()
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

private struct MemoryDetailView: View {
    let memory: PassingMemory
    @State private var showPlaylistAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(memory.date.formatted(.dateTime.year().month().day()))
                        .font(.subheadline.bold())
                        .foregroundStyle(PassingColors.lime)
                    Text(memory.eventName).font(.system(size: 32, weight: .black, design: .rounded))
                    Label(memory.venue, systemImage: "mappin.and.ellipse").foregroundStyle(PassingColors.secondaryText)
                    Text("\(memory.peopleCount)人の \(memory.songs.count)曲と出会いました")
                        .font(.headline)
                        .padding(.top, 8)
                }
                Button { showPlaylistAlert = true } label: {
                    Label("Apple Musicにプレイリストを作成", systemImage: "music.note.list")
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
        .navigationDestination(for: EncounteredSong.self) { item in
            SongDetailView(item: item)
        }
        .passingBackground()
        .alert("プレイリストを作成しました", isPresented: $showPlaylistAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("「PASSING — \(memory.eventName)」をApple Musicに追加しました。")
        }
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

private struct SongDetailView: View {
    let item: EncounteredSong

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
            Button {} label: { Label("試聴する", systemImage: "play.fill") }
                .buttonStyle(PrimaryButtonStyle(destructive: true))
            Button {} label: { Label("Apple Musicで聴く", systemImage: "arrow.up.right") }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 10)
        }
        .padding(22)
        .navigationBarTitleDisplayMode(.inline)
        .passingBackground()
    }
}
