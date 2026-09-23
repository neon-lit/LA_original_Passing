import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: PassingStore
    @EnvironmentObject private var previewPlayer: PreviewPlayer

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack { HomeView() }
                .tabItem { Label("ホーム", systemImage: "house.fill") }
                .tag(AppTab.home)
            NavigationStack { MemoryListView() }
                .tabItem { Label("メモリー", systemImage: "sparkles.rectangle.stack.fill") }
                .tag(AppTab.memory)
        }
        .tint(PassingColors.lime)
        .onChange(of: store.selectedTab) { _, _ in
            previewPlayer.stop()
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: PassingStore
    @EnvironmentObject private var previewPlayer: PreviewPlayer
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
                .simultaneousGesture(TapGesture().onEnded { previewPlayer.stop() })
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
                Button { previewPlayer.toggle(song: store.todaySong) } label: {
                    PreviewButtonLabel(song: store.todaySong)
                }
                .disabled(store.todaySong.previewURL == nil)
                Button {
                    previewPlayer.stop()
                    showSongPicker = true
                } label: {
                    Label("曲を変更", systemImage: "arrow.triangle.2.circlepath")
                }
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
            .simultaneousGesture(TapGesture().onEnded { previewPlayer.stop() })
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 22)
            .padding(.bottom, 14)
        }
        .padding(.top, 8)
        .passingBackground()
        .sheet(isPresented: $showSongPicker, onDismiss: { previewPlayer.stop() }) { SongPickerSheet() }
        .onDisappear { previewPlayer.stop() }
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
    @EnvironmentObject private var previewPlayer: PreviewPlayer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchService = AppleMusicSearchService()
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                if query.isEmpty {
                    ContentUnavailableView("Apple Musicから検索", systemImage: "music.note", description: Text("曲名またはアーティスト名を入力してください"))
                        .listRowBackground(Color.clear)
                } else if searchService.isSearching {
                    HStack { Spacer(); ProgressView("検索中…"); Spacer() }
                        .listRowBackground(Color.clear)
                } else if let errorMessage = searchService.errorMessage {
                    ContentUnavailableView("検索結果", systemImage: "music.note", description: Text(errorMessage))
                        .listRowBackground(Color.clear)
                }

                ForEach(searchService.results) { song in
                    HStack(spacing: 14) {
                        Button {
                            store.todaySong = song
                            previewPlayer.stop()
                            dismiss()
                        } label: {
                            CoverArt(song: song, size: 54)
                            VStack(alignment: .leading) {
                                Text(song.title).font(.headline).lineLimit(1)
                                Text(song.artist).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        if song.previewURL != nil {
                            Button { previewPlayer.toggle(song: song) } label: {
                                if previewPlayer.loadingSongID == song.id {
                                    ProgressView().tint(PassingColors.lime)
                                } else {
                                    Image(systemName: previewPlayer.playingSongID == song.id ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.title2)
                                }
                            }
                            .buttonStyle(.plain)
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
                    Button("閉じる") {
                        previewPlayer.stop()
                        dismiss()
                    }
                }
            }
            .passingBackground()
        }
        .preferredColorScheme(.dark)
        .task(id: query) {
            guard !query.isEmpty else {
                await searchService.search(for: "")
                return
            }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await searchService.search(for: query)
        }
        .onDisappear { previewPlayer.stop() }
    }
}
