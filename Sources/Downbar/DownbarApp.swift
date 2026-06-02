import SwiftUI

@main
struct DownbarApp: App {
    @StateObject private var monitor = StatusMonitor()
    @Environment(\.openWindow) private var openWindow

    private static let onboardedKey = "hasOnboarded"

    init() {
        Notifier.configureNotificationDelegate()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(monitor: monitor)
                .task { presentOnboardingIfNeeded() }
        } label: {
            Image(nsImage: MenuBarIconRenderer.nsImage(for: monitor.aggregate))
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(monitor: monitor)
        }

        Window("Welcome to Downbar", id: "onboarding") {
            OnboardingView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    /// Show the first-run intro exactly once, opening its window and bringing the
    /// app forward since an LSUIElement app doesn't normally take focus.
    private func presentOnboardingIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.onboardedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.onboardedKey)
        openWindow(id: "onboarding")
        NSApp.activate(ignoringOtherApps: true)
    }
}
