import Combine
import SwiftUI
import UIKit

enum PassingColors {
    static let background = Color(red: 0.025, green: 0.035, blue: 0.075)
    static let surface = Color.white.opacity(0.075)
    static let surfaceStrong = Color.white.opacity(0.105)
    static let stroke = Color.white.opacity(0.10)
    static let lime = Color(red: 0.20, green: 0.62, blue: 1.0)
    static let cyan = Color(red: 0.18, green: 0.82, blue: 1.0)
    static let violet = Color(red: 0.28, green: 0.32, blue: 0.96)
    static let secondaryText = Color.white.opacity(0.62)
    static let primaryGradient = LinearGradient(
        colors: [lime, Color(red: 0.22, green: 0.45, blue: 1.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct CoverArt: View {
    let song: Song
    var size: CGFloat = 72
    @StateObject private var loader = ArtworkImageLoader()

    var body: some View {
        ZStack {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: song.colors.first?.opacity(0.3) ?? .clear, radius: 24, y: 12)
        .task(id: song.artworkCacheKey) {
            await loader.load(song: song)
        }
    }

    private var placeholder: some View {
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
    }
}

@MainActor
private final class ArtworkImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private static let memoryCache = NSCache<NSString, UIImage>()
    private var loadedKey: String?

    func load(song: Song) async {
        let key = song.artworkCacheKey
        guard loadedKey != key else { return }
        loadedKey = key
        image = nil

        if let cachedImage = Self.memoryCache.object(forKey: key as NSString) {
            image = cachedImage
            return
        }

        if let diskImage = Self.loadFromDisk(key: key) {
            Self.memoryCache.setObject(diskImage, forKey: key as NSString)
            image = diskImage
            return
        }

        guard let artworkURL = await AppleMusicLinkResolver.resolveArtworkURL(for: song) else { return }
        if await download(from: artworkURL, key: key) {
            return
        }

        if song.artworkURL != nil,
           let refreshedURL = await AppleMusicLinkResolver.resolveArtworkURL(for: song, refresh: true),
           refreshedURL != artworkURL {
            _ = await download(from: refreshedURL, key: key)
        }
    }

    private func download(from artworkURL: URL, key: String) async -> Bool {
        for attempt in 0..<3 {
            do {
                var request = URLRequest(url: artworkURL)
                request.cachePolicy = .returnCacheDataElseLoad
                request.timeoutInterval = 20
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      200..<300 ~= httpResponse.statusCode,
                      let downloadedImage = UIImage(data: data) else {
                    throw URLError(.cannotDecodeContentData)
                }

                guard loadedKey == key else { return false }
                Self.memoryCache.setObject(downloadedImage, forKey: key as NSString)
                Self.saveToDisk(data, key: key)
                image = downloadedImage
                return true
            } catch {
                guard attempt < 2 else { return false }
                try? await Task.sleep(for: .milliseconds(350 * (attempt + 1)))
            }
        }
        return false
    }

    private static func loadFromDisk(key: String) -> UIImage? {
        guard let url = cacheURL(for: key),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private static func saveToDisk(_ data: Data, key: String) {
        guard let url = cacheURL(for: key) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }

    private static func cacheURL(for key: String) -> URL? {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let safeKey = key.replacingOccurrences(of: "/", with: "_")
        return cachesDirectory
            .appendingPathComponent("PASSINGArtwork", isDirectory: true)
            .appendingPathComponent(safeKey)
            .appendingPathExtension("image")
    }
}

private extension Song {
    var artworkCacheKey: String {
        musicItemID ?? id.uuidString
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
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                destructive
                    ? AnyShapeStyle(Color.white.opacity(0.11))
                    : AnyShapeStyle(PassingColors.primaryGradient)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(destructive ? PassingColors.stroke : .white.opacity(0.16), lineWidth: 1)
            }
            .shadow(
                color: destructive ? .clear : PassingColors.lime.opacity(configuration.isPressed ? 0.12 : 0.28),
                radius: 18,
                y: 9
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(!isEnabled ? 0.42 : configuration.isPressed ? 0.84 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

struct PassingSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(PassingColors.secondaryText)
            }
        }
    }
}

private struct PassingCardModifier: ViewModifier {
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(PassingColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(PassingColors.stroke, lineWidth: 1)
            }
    }
}

extension View {
    func passingBackground() -> some View {
        background {
            LinearGradient(
                colors: [PassingColors.background, Color(red: 0.025, green: 0.045, blue: 0.105)],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(PassingColors.violet.opacity(0.20))
                        .frame(width: 320)
                        .blur(radius: 90)
                        .offset(x: 145, y: -175)
                }
                .overlay(alignment: .bottomLeading) {
                    Circle()
                        .fill(PassingColors.lime.opacity(0.10))
                        .frame(width: 280)
                        .blur(radius: 100)
                        .offset(x: -150, y: 150)
                }
        }
    }

    func passingCard(padding: CGFloat = 16) -> some View {
        modifier(PassingCardModifier(padding: padding))
    }

    func dismissesKeyboardOnOutsideTap() -> some View {
        background(KeyboardDismissInstaller().frame(width: 0, height: 0))
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> KeyboardDismissView {
        KeyboardDismissView()
    }

    func updateUIView(_ uiView: KeyboardDismissView, context: Context) {}

    static func dismantleUIView(_ uiView: KeyboardDismissView, coordinator: ()) {
        uiView.uninstall()
    }
}

private final class KeyboardDismissView: UIView, UIGestureRecognizerDelegate {
    private weak var installedWindow: UIWindow?
    private lazy var tapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        return recognizer
    }()

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard installedWindow !== window else { return }
        uninstall()
        installedWindow = window
        window?.addGestureRecognizer(tapRecognizer)
    }

    func uninstall() {
        installedWindow?.removeGestureRecognizer(tapRecognizer)
        installedWindow = nil
    }

    @objc private func dismissKeyboard() {
        installedWindow?.endEditing(true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var touchedView = touch.view
        while let currentView = touchedView {
            if currentView is UITextField || currentView is UITextView {
                return false
            }
            touchedView = currentView.superview
        }
        return true
    }
}
