import SwiftUI

@main
struct ExhaleApp: App {
    @State private var model: AppModel

    init() {
        // A seeded launch replaces the whole model before first render, so the
        // harness never has to tap through onboarding to reach a screen.
        _model = State(initialValue: Seed.fromLaunchArguments() ?? AppModel.loaded())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)      // dark-only by design
                .tint(Palette.accent)
        }
    }
}
