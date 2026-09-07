import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("ホーム", systemImage: "house.fill") }
            NavigationStack { MemoryListView() }
                .tabItem { Label("メモリー", systemImage: "sparkles.rectangle.stack.fill") }
        }
        .tint(PassingColors.lime)
    }
}

private struct HomeView: View {
    @EnvironmentObject private var store: PassingStore
    @State private var showSongPicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                PassingLogo()
                Spacer()
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .frame(width: 42, height: 42)
                        .background(PassingColors.surface)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 22)
            Spacer()
            Text("今日の1曲")
                .font(.subheadline.bold())
                .foregroundStyle(PassingColors.secondaryText)
            CoverArt(song: store.todaySong, size: 248)
                .padding(.vertical, 26)
            Text(store.todaySong.title)
                .font(.system(size: 29, weight: .bold, design: .rounded))
            Text(store.todaySong.artist)
                .font(.title3)
                .foregroundStyle(PassingColors.secondaryText)
                .padding(.top, 5)
            HStack(spacing: 12) {
                Button {} label: { Label("試聴", systemImage: "play.fill") }
                Button { showSongPicker = true } label: { Label("曲を変更", systemImage: "arrow.triangle.2.circlepath") }
            }
            .buttonStyle(HomeCapsuleButtonStyle())
            .padding(.top, 24)
            Spacer()
            NavigationLink {
                PassingSessionView()
            } label: {
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                    Text("PASSING開始")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
        }
        .padding(.top, 8)
        .passingBackground()
        .sheet(isPresented: $showSongPicker) { SongPickerSheet() }
    }
}

private struct HomeCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(PassingColors.surface)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

struct SongPickerSheet: View {
    @EnvironmentObject private var store: PassingStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredSongs: [Song] {
        Song.samples.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.artist.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredSongs) { song in
                    Button {
                        store.todaySong = song
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            CoverArt(song: song, size: 54)
                            VStack(alignment: .leading) {
                                Text(song.title).font(.headline)
                                Text(song.artist).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .searchable(text: $query, prompt: "曲名・アーティスト名")
            .navigationTitle("今日の1曲を変更")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .passingBackground()
        }
        .preferredColorScheme(.dark)
    }
}
