import SwiftUI

struct ContentView: View {
    @StateObject private var store = PassingStore()
    @StateObject private var previewPlayer = PreviewPlayer()
    @StateObject private var locationService = LocationService()
    @StateObject private var nearbyPassingService = NearbyPassingService()

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
        .environmentObject(locationService)
        .environmentObject(nearbyPassingService)
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
        .alert(
            "位置情報を利用できません",
            isPresented: Binding(
                get: { locationService.errorMessage != nil },
                set: { isPresented in
                    if !isPresented { locationService.clearError() }
                }
            )
        ) {
            Button("OK", role: .cancel) { locationService.clearError() }
        } message: {
            Text(locationService.errorMessage ?? "")
        }
    }
}
