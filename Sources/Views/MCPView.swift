import SwiftUI

struct MCPView: View {
    // Owned by AppShell so unsaved edits survive sidebar section switches.
    @ObservedObject var store: MCPStore
    var onChange: () -> Void = {}
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private func matches(_ server: MCPEdit) -> Bool {
        query.isEmpty ||
        server.name.localizedCaseInsensitiveContains(query) ||
        server.command.localizedCaseInsensitiveContains(query) ||
        server.args.localizedCaseInsensitiveContains(query) ||
        server.url.localizedCaseInsensitiveContains(query)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            WarningBanner(text: String(localized: "~/.claude.json is written by Claude Code at runtime. If it changes while editing, Save is blocked (use Reload). Other keys are preserved."))
            ScrollView {
                LazyVStack(spacing: Theme.Space.sm) {
                    ForEach($store.servers) { $server in
                        if matches(server) {
                            MCPServerCard(server: $server) {
                                store.remove(id: server.id)
                            }
                        }
                    }
                    Button {
                        store.add()
                    } label: {
                        Label("Add server", systemImage: "plus")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Space.xs)
                }
                .padding(Theme.Space.lg)
            }
            .background(Theme.bg)
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
            Text("MCP Servers")
                .font(Theme.Typo.serifTitle)
                .foregroundStyle(Theme.ink)
            Text("\(store.servers.count) servers")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.inkTertiary)
            Spacer()
            SearchField(prompt: String(localized: "Filter servers"), text: $query, focus: $searchFocused)
                .frame(width: 200)
        }
        .padding(.horizontal, Theme.Space.xl)
        .frame(height: Theme.Dim.topBarHeight + 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

// MARK: - Server card

private struct MCPServerCard: View {
    @Binding var server: MCPEdit
    let onDelete: () -> Void
    @State private var hovering = false
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            // Top row: name field / kind picker / delete
            HStack(spacing: Theme.Space.sm) {
                ThemedField(prompt: String(localized: "name"), text: $server.name)
                SegmentedControl(
                    selection: $server.kind,
                    options: [
                        (value: "stdio", label: "stdio"),
                        (value: "http",  label: "http"),
                        (value: "sse",   label: "sse")
                    ]
                )
                .frame(width: 170)
                IconButton("trash", role: .destructive, help: String(localized: "Delete server")) {
                    confirmingDelete = true
                }
            }

            // Field rows: stdio vs network
            if server.kind == "stdio" {
                MCPLabeledField(label: String(localized: "command"), prompt: String(localized: "command"), text: $server.command)
                MCPLabeledField(label: String(localized: "args"),    prompt: String(localized: "args"),    text: $server.args)
            } else {
                MCPLabeledField(label: String(localized: "url"), prompt: String(localized: "url"), text: $server.url)
            }
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(hovering: hovering)
        .onHover { hovering = $0 }
        .motion(Theme.Motion.quick, value: hovering)
        .confirmationDialog(
            "Delete server?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\u{201C}\(server.name.isEmpty ? "This server" : server.name)\u{201D} will be removed from the list. Nothing is written to disk until you save, and Discard still undoes this.")
        }
    }
}

// MARK: - Labeled field row

private struct MCPLabeledField: View {
    let label: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: Theme.Space.sm) {
            Text(label)
                .font(Theme.Typo.caption)
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 64, alignment: .leading)
            ThemedField(prompt: prompt, text: $text, mono: true)
        }
    }
}
