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
                    Text("PASSING中").font(.headline)
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
                Text(store.sessionStartedAt ?? .now, style: .timer)
                    .font(.subheadline.monospacedDigit().bold())
                    .foregroundStyle(PassingColors.lime)
            }
            .padding(22)
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
            .frame(height: 360)
            Text("近くの音楽を探しています").font(.title2.bold())
            Text(nearbyStatusText)
                .font(.subheadline)
                .foregroundStyle(PassingColors.secondaryText)
                .padding(.top, 7)
            HStack(spacing: 0) {
                counter(value: store.sessionPeopleCount, label: "人とすれ違い")
                Divider().frame(height: 45).overlay(.white.opacity(0.16))
                counter(value: store.sessionSongs.count, label: "曲と出会いました")
            }
            .padding(.vertical, 20)
            .background(PassingColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22))
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
            nearbyService.start(song: store.todaySong, location: locationService.lastLocation)
            animateRings = true
        }
        .onReceive(locationService.$lastLocation) { location in
            nearbyService.updateLocation(location)
        }
        .onReceive(nearbyService.$encounters) { encounters in
            for encounter in encounters {
                store.recordEncounter(
                    song: encounter.song,
                    peerID: encounter.id,
                    encounteredAt: encounter.encounteredAt
                )
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
        if MarketingCapture.isActive { return "位置情報・近距離通信を使用中" }
        #endif
        if !locationService.isTracking { return "位置情報の許可を確認中" }
        if nearbyService.isRunning { return "位置情報・近距離通信を使用中" }
        return "近距離通信を準備中"
    }

    private var nearbyStatusText: String {
        #if DEBUG
        if MarketingCapture.isActive { return "会場内のPASSINGを検出しています" }
        #endif
        return nearbyService.connectedPeerCount > 0
            ? "近くに \(nearbyService.connectedPeerCount) 台のPASSINGを検出"
            : "BluetoothとWi-Fiをオンにしてください"
    }

    private func counter(value: Int, label: String) -> some View {
        VStack(spacing: 5) {
            Text("\(value)").font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(PassingColors.lime)
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
