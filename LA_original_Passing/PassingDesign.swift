import SwiftUI

enum PassingColors {
    static let background = Color(red: 0.035, green: 0.04, blue: 0.065)
    static let surface = Color.white.opacity(0.075)
    static let lime = Color(red: 0.78, green: 1.0, blue: 0.25)
    static let violet = Color(red: 0.56, green: 0.32, blue: 1.0)
    static let secondaryText = Color.white.opacity(0.58)
}

struct CoverArt: View {
    let song: Song
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            LinearGradient(colors: song.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: size * 0.72)
                .blur(radius: size * 0.12)
                .offset(x: -size * 0.18, y: -size * 0.2)
            Image(systemName: song.symbol)
                .font(.system(size: size * 0.25, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: song.colors.first?.opacity(0.3) ?? .clear, radius: 24, y: 12)
    }
}

struct PassingLogo: View {
    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(PassingColors.lime.opacity(0.35), lineWidth: 2).frame(width: 29, height: 29)
                Circle().fill(PassingColors.lime).frame(width: 9, height: 9)
            }
            Text("PASSING")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .tracking(2.6)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var destructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(destructive ? .white : .black)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(destructive ? Color.white.opacity(0.12) : PassingColors.lime)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

extension View {
    func passingBackground() -> some View {
        background {
            PassingColors.background
                .ignoresSafeArea()
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(PassingColors.violet.opacity(0.18))
                        .frame(width: 300)
                        .blur(radius: 80)
                        .offset(x: 130, y: -160)
                }
        }
    }
}
