import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PassingStore
    @State private var showSongPicker = false

    var body: some View {
        List {
            Section("連携") {
                Toggle(isOn: $store.isMusicConnected) { Label("Apple Music", systemImage: "music.note") }
                Toggle(isOn: $store.isLocationEnabled) { Label("位置情報", systemImage: "location.fill") }
                Toggle(isOn: $store.notificationsEnabled) { Label("通知", systemImage: "bell.fill") }
            }
            Section("音楽") {
                Button { showSongPicker = true } label: {
                    HStack {
                        Label("今日の1曲", systemImage: "waveform")
                        Spacer()
                        Text(store.todaySong.title).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                NavigationLink { GenreSettingsView() } label: {
                    Label("好きな音楽ジャンル", systemImage: "guitars.fill")
                }
            }
            Section("PASSINGについて") {
                LabeledContent("バージョン", value: "1.0.0")
                HStack {
                    Label("プライバシーポリシー", systemImage: "hand.raised.fill")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                Text("PASSINGは人ではなく、音楽との偶然の出会いを残します。プロフィールや正確な位置情報が他のユーザーに公開されることはありません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("設定")
        .passingBackground()
        .sheet(isPresented: $showSongPicker) { SongPickerSheet() }
    }
}

private struct GenreSettingsView: View {
    @EnvironmentObject private var store: PassingStore

    var body: some View {
        List(MusicGenre.allCases) { genre in
            Button {
                if store.selectedGenres.contains(genre) { store.selectedGenres.remove(genre) }
                else { store.selectedGenres.insert(genre) }
            } label: {
                HStack {
                    Text(genre.rawValue)
                    Spacer()
                    if store.selectedGenres.contains(genre) {
                        Image(systemName: "checkmark").foregroundStyle(PassingColors.lime)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("好きなジャンル")
        .passingBackground()
    }
}
