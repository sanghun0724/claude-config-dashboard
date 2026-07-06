import SwiftUI
import AppKit

@main
struct ClaudeConfigDashboardApp: App {
    /// ◐ light/dark override (design: per-window theme toggle). "system" follows macOS.
    @AppStorage("appearance") private var appearance = "system"
    /// UI display language. "system" follows macOS; anything else needs a relaunch to
    /// take effect (see `relaunchApp()`), since the app's chosen localization is fixed
    /// for a process's whole lifetime.
    @AppStorage("appLanguage") private var appLanguage = "system"

    init() {
        if appLanguage == "system" {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([appLanguage], forKey: "AppleLanguages")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
                .frame(minWidth: 980, minHeight: 620)
                .preferredColorScheme(
                    appearance == "light" ? .light : appearance == "dark" ? .dark : nil
                )
        }
        .defaultSize(width: 1180, height: 800)
        .windowToolbarStyle(.unified)
    }
}

/// Relaunches the app in a fresh process so a changed `appLanguage`/AppleLanguages
/// override takes effect immediately instead of requiring a manual quit and reopen.
func relaunchApp() {
    let config = NSWorkspace.OpenConfiguration()
    config.createsNewApplicationInstance = true
    NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
        DispatchQueue.main.async { NSApp.terminate(nil) }
    }
}
