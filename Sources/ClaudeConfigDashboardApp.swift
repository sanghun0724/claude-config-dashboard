import SwiftUI

@main
struct ClaudeConfigDashboardApp: App {
    /// ◐ light/dark override (design: per-window theme toggle). "system" follows macOS.
    @AppStorage("appearance") private var appearance = "system"

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
