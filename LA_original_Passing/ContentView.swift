import SwiftUI

struct ContentView: View {
    @StateObject private var store = PassingStore()

    var body: some View {
        Group {
            if store.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environmentObject(store)
        .preferredColorScheme(.dark)
    }
}
