import SwiftUI

enum ConfigSection: String, CaseIterable, Identifiable {
    case skills = "Skills"
    case agents = "Agents"
    case commands = "Commands"
    case mcp = "MCP Servers"
    case hooks = "Hooks"
    case settings = "Settings"
    case assistant = "Assistant"

    var id: String { rawValue }

    /// Sidebar display name — English section names, Korean for the analysis tool
    /// (design: 도구 › 분석).
    var title: String {
        self == .assistant ? "분석" : rawValue
    }
}

/// Custom two-pane shell. Replaces NavigationSplitView with a hand-built rail + detail.
/// Owns `selection` and the single shared `SettingsStore` (Hooks and Settings edit the
/// same settings.json — they MUST share one instance). Scan runs off the main thread.
struct AppShell: View {
    @State private var data = ConfigData.empty
    @State private var selection: ConfigSection = .skills
    @State private var isScanning = false
    @State private var hasLoaded = false
    @StateObject private var settings = SettingsStore()
    @StateObject private var assistant = AssistantStore()

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(
                selection: $selection,
                counts: count,
                onReload: { Task { await reload() } },
                isScanning: isScanning
            )
            detail
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
        .task { await reload() }
    }

    @ViewBuilder
    private var detail: some View {
        ZStack {
            Theme.bg
            if isScanning && !hasLoaded {
                SkeletonList()
            } else {
                section
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var section: some View {
        switch selection {
        case .skills:
            SkillsView(skills: data.skills, dir: "\(data.claudeDir)/skills", onChange: triggerReload)
        case .agents:
            AgentsView(agents: data.agents, dir: "\(data.claudeDir)/agents", onChange: triggerReload)
        case .commands:
            CommandsView(commands: data.commands, dir: "\(data.claudeDir)/commands", onChange: triggerReload)
        case .mcp:
            MCPView(onChange: triggerReload)
        case .hooks:
            HooksView(store: settings, onChange: triggerReload)
        case .settings:
            SettingsView(store: settings, onChange: triggerReload)
        case .assistant:
            AssistantView(data: data, assistant: assistant, onChange: triggerReload)
        }
    }

    private func count(_ section: ConfigSection) -> Int {
        switch section {
        case .skills: return data.skills.count
        case .agents: return data.agents.count
        case .commands: return data.commands.count
        case .mcp: return data.mcpServers.count
        case .hooks: return data.hooks.count
        case .settings: return data.allow.count + data.deny.count + data.ask.count + data.envVars.count
        case .assistant: return -1   // not a count — sidebar hides it
        }
    }

    private func triggerReload() { Task { await reload() } }

    private func reload() async {
        isScanning = true
        let scanned = await Task.detached(priority: .userInitiated) {
            ConfigScanner().scan()
        }.value
        data = scanned
        hasLoaded = true
        isScanning = false
    }
}

/// Warm placeholder cards shown during the first scan — paper cards, redacted.
private struct SkeletonList: View {
    var body: some View {
        VStack(spacing: Theme.Space.sm) {
            ForEach(0..<6, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Configuration item name")
                        .font(.system(size: 14, weight: .semibold))
                    Text("A short description line standing in while scanning ~/.claude")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary)
                }
                .padding(Theme.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
            }
            Spacer()
        }
        .padding(Theme.Space.lg)
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
    }
}
