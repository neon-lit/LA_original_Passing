import SwiftUI
import MusicKit

struct OnboardingView: View {
    @EnvironmentObject private var store: PassingStore
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                PassingLogo()
                Spacer()
                Text("\(step + 1) / 5")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(PassingColors.secondaryText)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            ProgressView(value: Double(step + 1), total: 5)
                .tint(PassingColors.lime)
                .padding(.horizontal, 24)
                .padding(.top, 18)

            TabView(selection: $step) {
                WelcomeStep().tag(0)
                GenreStep().tag(1)
                SongSelectionStep().tag(2)
                PermissionStep(
                    icon: "music.note",
                    eyebrow: "APPLE MUSIC",
                    title: "出会った曲を、\nそのまま聴こう。",
                    detail: "Apple Musicと連携すると、曲の再生やイベントごとのプレイリスト作成ができます。",
                    buttonTitle: store.isMusicConnected ? "連携済み" : "Apple Musicと連携",
                    isComplete: store.isMusicConnected
                ) {
                    Task {
                        store.isMusicConnected = await MusicAuthorization.request() == .authorized
                    }
                }
                .tag(3)
                PermissionStep(
                    icon: "location.fill",
                    eyebrow: "LOCATION",
                    title: "近くにいた音楽と、\nすれ違うために。",
                    detail: "位置情報はPASSING中だけ使用します。あなたの行動履歴や正確な位置が他の人に表示されることはありません。",
                    buttonTitle: store.isLocationEnabled ? "設定済み" : "位置情報を許可",
                    isComplete: store.isLocationEnabled
                ) { store.isLocationEnabled = true }
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 12) {
                if step > 0 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .frame(width: 56, height: 58)
                            .background(PassingColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                }
                Button {
                    if step == 4 {
                        store.hasCompletedOnboarding = true
                    } else {
                        withAnimation { step += 1 }
                    }
                } label: {
                    HStack {
                        Text(step == 4 ? "PASSINGをはじめる" : "次へ")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
        }
        .passingBackground()
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            ZStack {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(PassingColors.lime.opacity(0.32 - Double(index) * 0.08), lineWidth: 1.5)
                        .frame(width: CGFloat(105 + index * 62))
                }
                Circle().fill(PassingColors.lime).frame(width: 20, height: 20).shadow(color: PassingColors.lime, radius: 24)
                Image(systemName: "music.note").font(.system(size: 28, weight: .bold)).offset(x: 76, y: -60)
                Image(systemName: "music.quarternote.3").font(.system(size: 23, weight: .bold)).offset(x: -91, y: 48)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            Text("偶然の1曲と、\nすれ違おう。")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .tracking(-1.5)
            Text("ライブやフェスで近くにいた、知らない誰かの“届けたい1曲”と出会うアプリです。")
                .font(.body)
                .foregroundStyle(PassingColors.secondaryText)
                .lineSpacing(7)
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct GenreStep: View {
    @EnvironmentObject private var store: PassingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("YOUR TASTE").font(.caption.bold()).tracking(2).foregroundStyle(PassingColors.lime)
            Text("好きな音楽を\n教えてください。")
                .font(.system(size: 36, weight: .black, design: .rounded))
            Text("いくつでも選べます。今後の音楽との出会いに活かされます。")
                .foregroundStyle(PassingColors.secondaryText)
                .padding(.bottom, 18)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108))], spacing: 12) {
                ForEach(MusicGenre.allCases) { genre in
                    Button {
                        if store.selectedGenres.contains(genre) { store.selectedGenres.remove(genre) }
                        else { store.selectedGenres.insert(genre) }
                    } label: {
                        Text(genre.rawValue)
                            .font(.subheadline.bold())
                            .foregroundStyle(store.selectedGenres.contains(genre) ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(store.selectedGenres.contains(genre) ? PassingColors.lime : PassingColors.surface)
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct SongSelectionStep: View {
    @EnvironmentObject private var store: PassingStore
    @EnvironmentObject private var previewPlayer: PreviewPlayer
    @StateObject private var searchService = AppleMusicSearchService()
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 22)
            Text("TODAY'S ONE SONG").font(.caption.bold()).tracking(2).foregroundStyle(PassingColors.lime)
            Text("今日、誰かに\n届けたい1曲。")
                .font(.system(size: 34, weight: .black, design: .rounded))
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("曲名・アーティスト名で検索", text: $query).textInputAutocapitalization(.never)
            }
            .padding(16)
            .background(PassingColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            ScrollView {
                LazyVStack(spacing: 10) {
                    if query.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "music.note.list").font(.largeTitle).foregroundStyle(PassingColors.lime)
                            Text("Apple Musicから曲を検索").font(.headline)
                            Text("曲名またはアーティスト名を入力してください")
                                .font(.caption)
                                .foregroundStyle(PassingColors.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 44)
                    } else if searchService.isSearching {
                        ProgressView("Apple Musicを検索中…").tint(PassingColors.lime).padding(.top, 44)
                    } else if let errorMessage = searchService.errorMessage {
                        ContentUnavailableView("検索結果", systemImage: "music.note", description: Text(errorMessage))
                    }

                    ForEach(searchService.results) { song in
                        HStack(spacing: 14) {
                            Button { store.todaySong = song } label: {
                                HStack(spacing: 14) {
                                    CoverArt(song: song, size: 58)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(song.title).font(.headline).lineLimit(1)
                                        Text(song.artist).font(.subheadline).foregroundStyle(PassingColors.secondaryText).lineLimit(1)
                                    }
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
                            }
                            Button { store.todaySong = song } label: {
                                Image(systemName: store.todaySong.musicItemID == song.musicItemID ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(store.todaySong.musicItemID == song.musicItemID ? PassingColors.lime : .white.opacity(0.3))
                            }
                        }
                        .padding(10)
                        .background(store.todaySong.musicItemID == song.musicItemID ? PassingColors.lime.opacity(0.08) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .scrollIndicators(.hidden)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
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

private struct PermissionStep: View {
    let icon: String
    let eyebrow: String
    let title: String
    let detail: String
    let buttonTitle: String
    let isComplete: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(PassingColors.violet.opacity(0.18)).frame(width: 180)
                Circle().stroke(PassingColors.violet.opacity(0.45), lineWidth: 1).frame(width: 135)
                Image(systemName: icon).font(.system(size: 54, weight: .bold)).foregroundStyle(PassingColors.lime)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            Text(eyebrow).font(.caption.bold()).tracking(2).foregroundStyle(PassingColors.lime)
            Text(title).font(.system(size: 36, weight: .black, design: .rounded))
            Text(detail).foregroundStyle(PassingColors.secondaryText).lineSpacing(6)
            Button(action: action) {
                Label(buttonTitle, systemImage: isComplete ? "checkmark.circle.fill" : icon)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(isComplete ? PassingColors.lime.opacity(0.15) : PassingColors.surface)
                    .foregroundStyle(isComplete ? PassingColors.lime : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
