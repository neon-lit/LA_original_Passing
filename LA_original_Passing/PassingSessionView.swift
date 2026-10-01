import SwiftUI

struct PassingSessionView: View {
    @EnvironmentObject private var store: PassingStore
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var nearbyService: NearbyPassingService
    @Environment(\.dismiss) private var dismiss
    @State private var animateRings = false
    @State private var showFinishSheet: Bool
    @State private var eventName: String
    @State private var venueName: String
    @State private var duplicateNotice: DuplicateEncounterNotice?

    init() {
        #if DEBUG
        let isSummaryCapture = MarketingCapture.isActive && MarketingCapture.showFinishSheetOnAppear
        _showFinishSheet = State(initialValue: isSummaryCapture)
        _eventName = State(initialValue: isSummaryCapture ? "SUMMER SONIC 2026" : "")
        _venueName = State(initialValue: isSummaryCapture ? "ZOZOマリンスタジアム" : "")
        #else
        _showFinishSheet = State(initialValue: false)
        _eventName = State(initialValue: "")
        _venueName = State(initialValue: "")
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PASSING中")
                        .font(.headline)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(locationService.isTracking ? PassingColors.lime : .orange)
                            .frame(width: 7)
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(PassingColors.secondaryText)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("経過時間")
                        .font(.caption2)
                        .foregroundStyle(PassingColors.secondaryText)
                    Text(store.sessionStartedAt ?? .now, style: .timer)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(PassingColors.lime)
                }
            }
            .passingCard(padding: 15)
            .padding(.horizontal, 22)
            .padding(.top, 12)
            Spacer()
            ZStack {
                ForEach(0..<4) { index in
                    Circle()
                        .stroke(PassingColors.lime.opacity(0.34 - Double(index) * 0.065), lineWidth: 1.4)
                        .frame(width: CGFloat(92 + index * 62))
                        .scaleEffect(animateRings ? 1.1 : 0.82)
                        .opacity(animateRings ? 0.2 : 0.9)
                        .animation(
                            .easeOut(duration: 2.4).repeatForever(autoreverses: false).delay(Double(index) * 0.28),
                            value: animateRings
                        )
                }
                Circle()
                    .fill(PassingColors.lime)
                    .frame(width: 54, height: 54)
                    .shadow(color: PassingColors.lime.opacity(0.75), radius: 30)
                    .overlay(Image(systemName: "music.note").foregroundStyle(.black).font(.title2.bold()))
            }
            .frame(height: 330)
            Text("近くの音楽を探しています").font(.title2.bold())
            Text(nearbyStatusText)
                .font(.subheadline)
                .foregroundStyle(PassingColors.secondaryText)
                .padding(.top, 7)
            if let duplicateNotice {
                HStack(spacing: 12) {
                    CoverArt(song: duplicateNotice.song, size: 46)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("同じ曲とすれ違いました")
                            .font(.caption.bold())
                            .foregroundStyle(PassingColors.lime)
                        Text(duplicateNotice.song.title)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("+\(duplicateNotice.count)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(PassingColors.lime)
                }
                .padding(12)
                .background(PassingColors.lime.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PassingColors.lime.opacity(0.45), lineWidth: 1)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            HStack(spacing: 0) {
                counter(value: store.sessionPeopleCount, label: "人とすれ違い", symbol: "person.2.fill")
                Divider().frame(height: 48).overlay(PassingColors.stroke)
                counter(value: store.sessionSongs.count, label: "曲と出会いました", symbol: "music.note.list")
            }
            .padding(.vertical, 20)
            .background(PassingColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(PassingColors.stroke, lineWidth: 1)
            }
            .padding(22)
            Spacer()
            Button("PASSINGを終了") {
                venueName = locationService.displayPlace
                showFinishSheet = true
            }
                .buttonStyle(PrimaryButtonStyle(destructive: true))
                .padding(22)
        }
        .passingBackground()
        .navigationBarBackButtonHidden()
        .onAppear {
            #if DEBUG
            if MarketingCapture.isActive {
                animateRings = true
                return
            }
            #endif
            store.startPassing()
            locationService.startTracking()
            nearbyService.start(song: store.todaySong)
            animateRings = true
        }
        .onReceive(nearbyService.$encounters) { encounters in
            for encounter in encounters {
                let result = store.recordEncounter(
                    song: encounter.song,
                    peerID: encounter.id,
                    encounteredAt: encounter.encounteredAt
                )
                if case let .duplicate(song, count) = result {
                    withAnimation(.spring(response: 0.35)) {
                        duplicateNotice = DuplicateEncounterNotice(song: song, count: count)
                    }
                }
            }
        }
        .task(id: duplicateNotice?.id) {
            guard duplicateNotice != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation {
                duplicateNotice = nil
            }
        }
        .sheet(isPresented: $showFinishSheet) {
            finishSheet
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.visible)
        }
        .alert(
            "近距離通信エラー",
            isPresented: Binding(
                get: { nearbyService.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { nearbyService.clearError() }
                }
            )
        ) {
            Button("OK", role: .cancel) { nearbyService.clearError() }
        } message: {
            Text(nearbyService.errorMessage ?? "")
        }
    }

    private var statusText: String {
        #if DEBUG
        if MarketingCapture.isActive { return "Bluetooth・位置情報を使用中" }
        #endif
        if !locationService.isTracking { return "位置情報の許可を確認中" }
        if nearbyService.isRunning { return "Bluetooth・位置情報を使用中" }
        return "Bluetooth通信を準備中"
    }

    private var nearbyStatusText: String {
        #if DEBUG
        if MarketingCapture.isActive { return "会場内のPASSINGを検出しています" }
        #endif
        return nearbyService.connectedPeerCount > 0
            ? "Bluetooth LEで近くに \(nearbyService.connectedPeerCount) 台のPASSINGを検出"
            : "Bluetooth LEで近くのPASSINGを探しています"
    }

    private func counter(value: Int, label: String, symbol: String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.caption.bold())
                Text("\(value)")
                    .font(.system(size: 32, weight: .black, design: .rounded))
            }
            .foregroundStyle(PassingColors.lime)
            Text(label).font(.caption).foregroundStyle(PassingColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var finishSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("今日のPASSINGを保存").font(.title2.bold())
            Text("イベント名").font(.caption.bold()).foregroundStyle(PassingColors.secondaryText)
            TextField("例：SUMMER SONIC 2026", text: $eventName)
                .padding(16)
                .background(PassingColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Text("会場・場所").font(.caption.bold()).foregroundStyle(PassingColors.secondaryText)
            TextField("建物名または住所", text: $venueName)
                .padding(16)
                .background(PassingColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Spacer()
            Button("保存して終了") {
                store.finishPassing(eventName: eventName, venue: venueName)
                locationService.stopTracking()
                nearbyService.stop()
                showFinishSheet = false
                dismiss()
                DispatchQueue.main.async {
                    store.selectedTab = .memory
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .passingBackground()
    }
}

private struct DuplicateEncounterNotice: Identifiable {
    let id = UUID()
    let song: Song
    let count: Int
}
