import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    /// Unsaved work living outside this store (e.g. MCP edits held by AppShell) —
    /// folded into the Restart Now warning so a relaunch can't silently drop it.
    var extraUnsaved: Bool = false
    var onChange: () -> Void = {}

    @State private var newRule = ""
    @State private var newKind: PermissionKind = .allow
    @State private var newEnvKey = ""
    @State private var newEnvValue = ""
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var canAdd: Bool {
        !newRule.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func filteredRules(_ kind: PermissionKind) -> [String] {
        let rules = store.rules(kind)
        guard !query.isEmpty else { return rules }
        return rules.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: Theme.Space.sm) {
                    ForEach(PermissionKind.allCases) { kind in
                        PermissionGroupCard(
                            kind: kind,
                            rules: filteredRules(kind),
                            onDelete: { store.removeRule(kind, value: $0) }
                        )
                    }
                    EnvSectionCard(
                        envVars: $store.envVars,
                        query: query,
                        newEnvKey: $newEnvKey,
                        newEnvValue: $newEnvValue,
                        onAdd: {
                            store.addEnv(key: newEnvKey, value: newEnvValue)
                            newEnvKey = ""
                            newEnvValue = ""
                        },
                        onDelete: { store.removeEnv(id: $0) }
                    )
                    LanguageSectionCard(unsaved: store.hasChanges || extraUnsaved)
                }
                .padding(Theme.Space.lg)
            }
            .background(Theme.bg)

            addBar

            if let msg = store.statusMessage {
                StatusBar(message: msg, isError: store.isError)
            }
            ActionBar(store: store, onChange: onChange)
        }
        .statusFade(value: store.statusMessage)
        .background {
            Button("") { searchFocused = true }
                .keyboardShortcut("k", modifiers: .command)
                .hidden()
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Space.md) {
            Text("Settings")
                .font(Theme.Typo.serifTitle)
                .foregroundStyle(Theme.ink)
            Text("\(store.allow.count + store.ask.count + store.deny.count) rules · \(store.envVars.count) env")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.inkTertiary)
            Spacer()
            SearchField(prompt: String(localized: "Filter rules & env"), text: $query, focus: $searchFocused)
                .frame(width: 200)
        }
        .padding(.horizontal, Theme.Space.xl)
        .frame(height: Theme.Dim.topBarHeight + 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private var addBar: some View {
        HStack(spacing: Theme.Space.sm) {
            SegmentedControl(
                selection: $newKind,
                options: [
                    (value: .allow, label: PermissionKind.allow.displayLabel),
                    (value: .ask, label: PermissionKind.ask.displayLabel),
                    (value: .deny, label: PermissionKind.deny.displayLabel)
                ]
            )
            .fixedSize()
            ThemedField(prompt: String(localized: "Add rule, e.g. Bash(npm run test:*)"), text: $newRule)
                .onSubmit(add)
            Button("Add", action: add)
                .buttonStyle(GhostButtonStyle())
                .disabled(!canAdd)
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.vertical, Theme.Space.sm)
        .background(Theme.panel)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.divider).frame(height: 1)
        }
    }

    private func add() {
        store.addRule(newRule, to: newKind)
        newRule = ""
    }
}

// MARK: - Permission group card

private struct PermissionGroupCard: View {
    let kind: PermissionKind
    let rules: [String]
    let onDelete: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Space.sm) {
                Circle()
                    .fill(kind.color)
                    .frame(width: 8, height: 8)
                Text("\(kind.displayLabel) (\(rules.count))")
                    .font(Theme.Typo.label)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
            }
            .padding(Theme.Space.md)

            if !rules.isEmpty {
                Rectangle()
                    .fill(Theme.divider)
                    .frame(height: 1)

                ForEach(Array(rules.enumerated()), id: \.element) { index, rule in
                    HStack(spacing: Theme.Space.sm) {
                        Text(rule)
                            .font(Theme.Typo.mono)
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                        Spacer()
                        IconButton("trash", role: .destructive, help: String(localized: "Delete rule")) {
                            onDelete(rule)
                        }
                    }
                    .padding(.horizontal, Theme.Space.md)
                    .padding(.vertical, Theme.Space.sm)

                    if index < rules.count - 1 {
                        Rectangle()
                            .fill(Theme.divider)
                            .frame(height: 1)
                            .padding(.leading, Theme.Space.md)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

// MARK: - Environment section card

private struct EnvSectionCard: View {
    @Binding var envVars: [EnvVar]
    var query: String = ""
    @Binding var newEnvKey: String
    @Binding var newEnvValue: String
    let onAdd: () -> Void
    let onDelete: (UUID) -> Void

    // Env values may hold API keys/tokens — masked by default, revealed per-row on demand.
    @State private var revealed: Set<UUID> = []

    private var canAdd: Bool {
        !newEnvKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Space.sm) {
                Text("Environment (\(envVars.count))")
                    .font(Theme.Typo.label)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
            }
            .padding(Theme.Space.md)

            Rectangle()
                .fill(Theme.divider)
                .frame(height: 1)

            ForEach($envVars) { $env in
                if query.isEmpty || env.key.localizedCaseInsensitiveContains(query) {
                HStack(spacing: Theme.Space.sm) {
                    Text(env.key)
                        .font(Theme.Typo.mono)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    ThemedField(prompt: String(localized: "value"), text: $env.value, mono: true, isSecure: !revealed.contains(env.id))
                        .frame(maxWidth: 240)
                    IconButton(revealed.contains(env.id) ? "eye.slash" : "eye", help: String(localized: "Toggle value visibility")) {
                        if revealed.contains(env.id) { revealed.remove(env.id) } else { revealed.insert(env.id) }
                    }
                    IconButton("trash", role: .destructive, help: String(localized: "Delete env var")) {
                        onDelete(env.id)
                    }
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.vertical, Theme.Space.sm)

                Rectangle()
                    .fill(Theme.divider)
                    .frame(height: 1)
                    .padding(.leading, Theme.Space.md)
                }
            }

            HStack(spacing: Theme.Space.sm) {
                ThemedField(prompt: "NEW_KEY", text: $newEnvKey, mono: true)
                ThemedField(prompt: String(localized: "value"), text: $newEnvValue, mono: true)
                Button("Add") { onAdd() }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(!canAdd)
            }
            .padding(Theme.Space.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

// MARK: - Language section card

/// App display language. Takes effect on next launch — SwiftUI/String Catalog resolve
/// the process's localization once at startup (see `ClaudeConfigDashboardApp.init`), so a
/// live switch here can't hot-swap already-rendered text; Relaunch Now applies it instantly.
private struct LanguageSectionCard: View {
    /// Unsaved edits anywhere in the app — restart confirmation instead of silent loss.
    var unsaved: Bool = false
    @AppStorage("appLanguage") private var appLanguage = "system"
    /// Frozen at first render — the language this process actually launched with.
    @State private var launchLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
    @State private var confirmingRestart = false

    private let options: [(value: String, label: String)] = [
        ("system", String(localized: "System")),
        ("en", "English"),
        ("ko", "한국어"),
        ("es", "Español"),
        ("zh-Hans", "中文"),
        ("ja", "日本語"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Theme.Space.sm) {
                Text("Language")
                    .font(Theme.Typo.label)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
            }
            .padding(Theme.Space.md)

            Rectangle().fill(Theme.divider).frame(height: 1)

            HStack {
                Picker("", selection: $appLanguage) {
                    ForEach(options, id: \.value) { option in
                        Text(option.label).tag(option.value)
                    }
                }
                .labelsHidden()
                .fixedSize()
                Spacer()
            }
            .padding(Theme.Space.md)

            if appLanguage != launchLanguage {
                HStack(spacing: Theme.Space.sm) {
                    Text("Restart to apply the new language.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkTertiary)
                    Spacer()
                    Button("Restart Now") {
                        if unsaved { confirmingRestart = true } else { relaunchApp() }
                    }
                    .buttonStyle(GhostButtonStyle())
                }
                .padding(.horizontal, Theme.Space.md)
                .padding(.bottom, Theme.Space.md)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .confirmationDialog("Restart with unsaved changes?", isPresented: $confirmingRestart, titleVisibility: .visible) {
            Button("Restart Anyway", role: .destructive) { relaunchApp() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("There are unsaved changes that will be lost on restart. Save them first if you want to keep them.")
        }
    }
}
