import SwiftUI

struct AgentsView: View {
    let agents: [Agent]
    var dir: String = "~/.claude/agents"
    var onChange: () -> Void = {}
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var filtered: [Agent] {
        guard !query.isEmpty else { return agents }
        return agents.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if agents.isEmpty {
                    EmptyHint(label: String(localized: "agents"), dir: dir)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    EmptySearchHint(label: String(localized: "agents"), query: $query)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Space.sm) {
                            ForEach(filtered) { agent in
                                AgentCard(agent: agent, onChange: onChange)
                            }
                        }
                        .padding(Theme.Space.lg)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg)
        }
        .background {
            Button("") { searchFocused = true }
                .keyboardShortcut("k", modifiers: .command)
                .hidden()
        }
    }

    // MARK: - Header (serif title · count · search)

    private var header: some View {
        HStack(spacing: Theme.Space.md) {
            Text("Agents")
                .font(Theme.Typo.serifTitle)
                .foregroundStyle(Theme.ink)
            Text("\(agents.count) active")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.inkTertiary)
            Spacer()
            SearchField(prompt: String(localized: "Filter agents"), text: $query, focus: $searchFocused)
                .frame(width: 200)
            Button("New") {
                if createScaffold(in: dir, baseName: "new-agent", subfile: nil, template: agentTemplate) != nil {
                    onChange()
                }
            }
            .buttonStyle(GhostButtonStyle())
            .help("Create a new agent file")
        }
        .padding(.horizontal, Theme.Space.xl)
        .frame(height: Theme.Dim.topBarHeight + 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

/// Warm paper card for an agent — everything worth knowing (description, tools,
/// path) reads directly off the card, so browsing never needs a tap. Editing is
/// its own explicit step, same as Skills' reading room: the card is not a button.
private struct AgentCard: View {
    let agent: Agent
    let onChange: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(agent.name)
                    .font(Theme.Typo.serifRow)
                    .foregroundStyle(Theme.ink)
                if let model = agent.model {
                    Chip(text: model, tone: .neutral)
                }
                Spacer(minLength: Theme.Space.sm)
                NavigationLink {
                    FileEditorView(title: agent.name, path: agent.path, onChange: onChange)
                } label: {
                    Text("Edit")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accentStrong)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                .strokeBorder(Theme.accent, lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if !agent.description.isEmpty {
                Text(agent.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(2)
            }
            if let tools = agent.disallowedTools, !tools.isEmpty {
                Text("tools: \(tools)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Text(compactPath(agent.path))
                .font(.system(size: 11))
                .foregroundStyle(Theme.inkTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(agent.path)
                .pathContextMenu(agent.path)
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(hovering: hovering)
        .onHover { hovering = $0 }
        .motion(Theme.Motion.quick, value: hovering)
    }
}
