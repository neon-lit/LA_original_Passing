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
        ScrollView {
            VStack(spacing: 26) {
                HStack {
                    PassingLogo()
                    Spacer()
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(PassingColors.surfaceStrong)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(PassingColors.stroke, lineWidth: 1))
                    }
                    .simultaneousGesture(TapGesture().onEnded { previewPlayer.stop() })
                }
                .padding(.top, 8)

                VStack(spacing: 20) {
                    Text("TODAY'S ONE SONG")
                        .font(.caption.bold())
                        .tracking(2.1)
                        .foregroundStyle(PassingColors.lime)

                    ZStack {
                        Circle()
                            .fill(PassingColors.lime.opacity(0.16))
                            .frame(width: 260, height: 260)
                            .blur(radius: 36)
                        CoverArt(song: store.todaySong, size: 248)
                    }

                    VStack(spacing: 7) {
                        Text(store.todaySong.title)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                        Text(store.todaySong.artist)
                            .font(.title3)
                            .foregroundStyle(PassingColors.secondaryText)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 10) {
                    Button { previewPlayer.toggle(song: store.todaySong) } label: {
                        PreviewButtonLabel(song: store.todaySong)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(store.todaySong.previewURL == nil)
                    Button {
                        previewPlayer.stop()
                        showSongPicker = true
                    } label: {
                        Label("曲を変更", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(HomeCapsuleButtonStyle())
                .passingCard(padding: 10)

                Label("PASSING中はBluetooth LEで近くの人と1曲を交換します", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundStyle(PassingColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            NavigationLink {
                PassingSessionView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                    Text("PASSING開始")
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.subheadline.bold())
                }
                .padding(.horizontal, 20)
            }
            .simultaneousGesture(TapGesture().onEnded { previewPlayer.stop() })
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(PassingColors.background.opacity(0.92))
        }
        .passingBackground()
        .sheet(isPresented: $showSongPicker, onDismiss: { previewPlayer.stop() }) { SongPickerSheet() }
        .onDisappear { previewPlayer.stop() }
    }
}

private struct HomeCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(PassingColors.surfaceStrong)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
