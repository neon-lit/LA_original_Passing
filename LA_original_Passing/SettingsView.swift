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
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                settingsSection(title: "アプリの設定", subtitle: "PASSINGに必要な権限を管理します") {
                    VStack(spacing: 0) {
                        Button {
                            if locationService.authorizationStatus == .notDetermined {
                                locationService.requestPermission()
                            } else if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                openURL(settingsURL)
                            }
                        } label: {
                            SettingsActionRow(
                                title: "位置情報",
                                detail: locationService.statusText,
                                systemImage: "location.fill",
                                tint: PassingColors.lime,
                                detailColor: locationService.isAuthorized ? PassingColors.lime : PassingColors.secondaryText
                            )
                        }
                        Divider().overlay(PassingColors.stroke).padding(.leading, 62)
                        HStack(spacing: 14) {
                            SettingsIcon(systemImage: "bell.fill", tint: PassingColors.violet)
                            Text("通知").font(.body.weight(.semibold))
                            Spacer()
                            Toggle("", isOn: $store.notificationsEnabled)
                                .labelsHidden()
                                .tint(PassingColors.lime)
                        }
                        .padding(16)
                    }
                    .passingCard(padding: 0)
                }

                settingsSection(title: "今日の1曲", subtitle: "PASSINGで誰かへ届ける曲") {
                    Button {
                        previewPlayer.stop()
                        showSongPicker = true
                    } label: {
                        HStack(spacing: 14) {
                            CoverArt(song: store.todaySong, size: 58)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.todaySong.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(store.todaySong.artist)
                                    .font(.subheadline)
                                    .foregroundStyle(PassingColors.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.subheadline.bold())
                                .foregroundStyle(PassingColors.lime)
                                .frame(width: 36, height: 36)
                                .background(PassingColors.lime.opacity(0.12), in: Circle())
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .passingCard(padding: 14)
                }

                settingsSection(title: "PASSINGについて") {
                    VStack(spacing: 0) {
                        SettingsActionRow(
                            title: "プライバシー",
                            detail: "匿名で交換",
                            systemImage: "hand.raised.fill",
                            tint: PassingColors.cyan,
                            showsChevron: false
                        )
                        Divider().overlay(PassingColors.stroke).padding(.leading, 62)
                        SettingsActionRow(
                            title: "バージョン",
                            detail: appVersion,
                            systemImage: "info.circle.fill",
                            tint: PassingColors.secondaryText,
                            showsChevron: false
                        )
                    }
                    .passingCard(padding: 0)
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(PassingColors.lime)
                    Text("PASSINGは人ではなく、音楽との偶然の出会いを残します。プロフィールや正確な位置情報が他のユーザーに公開されることはありません。")
                    .font(.caption)
                    .foregroundStyle(PassingColors.secondaryText)
                    .lineSpacing(4)
                }
                .passingCard(padding: 16)
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("設定")
        .passingBackground()
        .sheet(isPresented: $showSongPicker, onDismiss: { previewPlayer.stop() }) { SongPickerSheet() }
        .onDisappear { previewPlayer.stop() }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private func settingsSection<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            PassingSectionHeader(title: title, subtitle: subtitle)
                .padding(.horizontal, 2)
            content()
        }
    }
}

private struct SettingsIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SettingsActionRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
    var detailColor = PassingColors.secondaryText
    var showsChevron = true

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemImage: systemImage, tint: tint)
            Text(title)
                .font(.body.weight(.semibold))
            Spacer()
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(detailColor)
                .lineLimit(1)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(PassingColors.secondaryText)
            }
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}
