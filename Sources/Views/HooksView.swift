import SwiftUI

struct HooksView: View {
    @ObservedObject var store: SettingsStore
    var onChange: () -> Void = {}

    @State private var newEvent = ""
    @State private var newMatcher = ""
    @State private var newCommand = ""

    private let events = [
        "PreToolUse", "PostToolUse", "PostToolUseFailure", "UserPromptSubmit",
        "SessionStart", "SessionEnd", "Stop", "SubagentStop", "Notification", "PermissionRequest"
    ]

    private var canAddHook: Bool {
        !newEvent.isEmpty && !newCommand.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: Theme.Space.sm) {
                    ForEach(store.hookEntries) { hook in
                        HookCard(hook: hook) {
                            store.removeHook(id: hook.id)
                        }
                    }
                    AddHookCard(
                        events: events,
                        newEvent: $newEvent,
                        newMatcher: $newMatcher,
                        newCommand: $newCommand,
                        canAdd: canAddHook
                    ) {
                        store.addHook(event: newEvent, matcher: newMatcher, command: newCommand)
                        newMatcher = ""
                        newCommand = ""
                    }
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
    }

    private var header: some View {
        HStack(spacing: Theme.Space.md) {
            Text("Hooks")
                .font(Theme.Typo.serifTitle)
                .foregroundStyle(Theme.ink)
            Text("\(store.hookEntries.count) hooks")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.inkTertiary)
            Spacer()
        }
        .padding(.horizontal, Theme.Space.xl)
        .frame(height: Theme.Dim.topBarHeight + 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

// MARK: - Hook card

private struct HookCard: View {
    let hook: HookEditEntry
    let onDelete: () -> Void
    @State private var hovering = false
    @State private var confirmingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            HStack(spacing: Theme.Space.sm) {
                Text(hook.event)
                    .font(Theme.Typo.heading)
                    .foregroundStyle(Theme.ink)
                Chip(text: "matcher: \(hook.matcher)")
                if hook.raw == nil {
                    Chip(text: "new", tone: .accent)
                }
                Spacer()
                IconButton("trash", role: .destructive, help: "Delete hook") {
                    confirmingDelete = true
                }
            }
            if !hook.commands.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    ForEach(Array(hook.commands.enumerated()), id: \.offset) { _, cmd in
                        Text(cmd)
                            .font(Theme.Typo.mono)
                            .foregroundStyle(Theme.inkSecondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(hovering: hovering)
        .onHover { hovering = $0 }
        .motion(Theme.Motion.quick, value: hovering)
        .confirmationDialog(
            "Delete hook?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The \(hook.event) hook will be removed from the list. Nothing is written to disk until you save, and Discard still undoes this.")
        }
    }
}

// MARK: - Add hook card

private struct AddHookCard: View {
    let events: [String]
    @Binding var newEvent: String
    @Binding var newMatcher: String
    @Binding var newCommand: String
    let canAdd: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            Text("Add hook")
                .font(Theme.Typo.heading)
                .foregroundStyle(Theme.ink)

            HStack {
                Text("Event")
                    .font(Theme.Typo.label)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                Menu {
                    Button("Select event…") { newEvent = "" }
                    Divider()
                    ForEach(events, id: \.self) { event in
                        Button(event) { newEvent = event }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(newEvent.isEmpty ? "Select event…" : newEvent)
                            .font(Theme.Typo.label)
                            .foregroundStyle(newEvent.isEmpty ? Theme.inkTertiary : Theme.ink)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            ThemedField(prompt: "matcher (e.g. * or Bash)", text: $newMatcher)
            ThemedField(prompt: "command", text: $newCommand, mono: true)

            HStack {
                Spacer()
                Button("Add hook") { onAdd() }
                    .buttonStyle(GhostButtonStyle())
                    .disabled(!canAdd)
            }
        }
        .padding(Theme.Space.md)
        .cardSurface()
    }
}
