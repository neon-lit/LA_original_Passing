import SwiftUI

struct ContentView: View {
    @StateObject private var store = PassingStore()
    @StateObject private var previewPlayer = PreviewPlayer()

    var body: some View {
        Group {
            if store.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environmentObject(store)
        .environmentObject(previewPlayer)
        .preferredColorScheme(.dark)
        .alert(
            "試聴できません",
            isPresented: Binding(
                get: { previewPlayer.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { previewPlayer.clearError() }
                }
            )
        ) {
            Button("OK", role: .cancel) { previewPlayer.clearError() }
        } message: {
            Text(previewPlayer.errorMessage ?? "")
        }
    }
}
