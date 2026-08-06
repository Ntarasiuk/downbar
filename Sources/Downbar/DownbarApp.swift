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
            MenuBarLabel(monitor: monitor)
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

/// The status-item icon. Also hosts the launch hook for screenshot automation:
/// start the app with `DOWNBAR_OPEN_SETTINGS=1` and Settings opens immediately,
/// so `scripts/screenshots.sh` doesn't need UI-scripting (accessibility) rights.
/// The label view is the only view that exists at launch in a MenuBarExtra app,
/// which is why the hook lives here.
private struct MenuBarLabel: View {
    @ObservedObject var monitor: StatusMonitor
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(nsImage: MenuBarIconRenderer.nsImage(for: monitor.aggregate))
            .task {
                guard ProcessInfo.processInfo.environment["DOWNBAR_OPEN_SETTINGS"] == "1" else { return }
                openSettings()
                // Give the Settings scene a beat to create its window, then
                // bring it to the front — an LSUIElement app isn't frontmost
                // at launch, so the window would otherwise open unfocused.
                try? await Task.sleep(nanoseconds: 500_000_000)
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first { $0.isVisible && !$0.title.isEmpty }?
                    .makeKeyAndOrderFront(nil)
            }
    }
}
