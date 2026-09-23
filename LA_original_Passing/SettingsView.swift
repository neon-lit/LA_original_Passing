import SwiftUI
import UIKit
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject private var store: PassingStore
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var previewPlayer: PreviewPlayer
    @Environment(\.openURL) private var openURL
    @State private var showSongPicker = false

    var body: some View {
        List {
            Section("連携") {
                Button {
                    if locationService.authorizationStatus == .notDetermined {
                        locationService.requestPermission()
                    } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        openURL(settingsURL)
                    }
                } label: {
                    HStack {
                        Label("位置情報", systemImage: "location.fill")
                        Spacer()
                        Text(locationService.statusText)
                            .font(.subheadline)
                            .foregroundStyle(locationService.isAuthorized ? PassingColors.lime : .secondary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle(isOn: $store.notificationsEnabled) { Label("通知", systemImage: "bell.fill") }
            }
            Section("音楽") {
                Button {
                    previewPlayer.stop()
                    showSongPicker = true
                } label: {
                    HStack {
                        Label("今日の1曲", systemImage: "waveform")
                        Spacer()
                        Text(store.todaySong.title).foregroundStyle(.secondary).lineLimit(1)
                    }
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
        .sheet(isPresented: $showSongPicker, onDismiss: { previewPlayer.stop() }) { SongPickerSheet() }
        .onDisappear { previewPlayer.stop() }
    }
}
