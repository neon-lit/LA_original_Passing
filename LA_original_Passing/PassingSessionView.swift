import SwiftUI
import Combine

struct PassingSessionView: View {
    @EnvironmentObject private var store: PassingStore
    @Environment(\.dismiss) private var dismiss
    @State private var animateRings = false
    @State private var showFinishSheet = false
    @State private var eventName = ""

    private let discoveryTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PASSING中").font(.headline)
                    HStack(spacing: 6) {
                        Circle().fill(PassingColors.lime).frame(width: 7)
                        Text("位置情報を取得しています").font(.caption).foregroundStyle(PassingColors.secondaryText)
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
            Text("画面を閉じても、そのままで大丈夫です")
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
            Button("PASSINGを終了") { showFinishSheet = true }
                .buttonStyle(PrimaryButtonStyle(destructive: true))
                .padding(22)
        }
        .passingBackground()
        .navigationBarBackButtonHidden()
        .onAppear {
            store.startPassing()
            animateRings = true
        }
        .onReceive(discoveryTimer) { _ in store.discoverSong() }
        .sheet(isPresented: $showFinishSheet) {
            finishSheet
                .presentationDetents([.height(380)])
                .presentationDragIndicator(.visible)
        }
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
            Text("イベント名は後からメモリーで変更できます。")
                .font(.caption)
                .foregroundStyle(PassingColors.secondaryText)
            Spacer()
            Button("保存して終了") {
                store.finishPassing(eventName: eventName)
                showFinishSheet = false
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .passingBackground()
    }
}
