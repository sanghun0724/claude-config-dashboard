import SwiftUI

struct CommandsView: View {
    let commands: [Command]
    var dir: String = "~/.claude/commands"
    var onChange: () -> Void = {}

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if commands.isEmpty {
                    EmptyHint(label: String(localized: "commands"), dir: dir)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Space.sm) {
                            ForEach(commands) { command in
                                CommandRow(command: command, onChange: onChange)
                            }
                        }
                        .padding(Theme.Space.lg)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg)
        }
    }

    // MARK: - Header (serif title · count)

    private var header: some View {
        HStack(spacing: Theme.Space.md) {
            Text("Commands")
                .font(Theme.Typo.serifTitle)
                .foregroundStyle(Theme.ink)
            Text("\(commands.count) active")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.inkTertiary)
            Spacer()
        }
        .padding(.horizontal, Theme.Space.xl)
        .frame(height: Theme.Dim.topBarHeight + 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }
}

/// Warm paper card for a command. Every command is a file (namespace directories
/// are flattened by the scanner). Name and path already say everything there is
/// to browse here, so the row itself is inert — the trailing button is the one
/// explicit way into the editor, matching the read-first pattern elsewhere.
private struct CommandRow: View {
    let command: Command
    let onChange: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: "doc.text")
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
                .frame(width: 16, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(command.name)
                    .font(Theme.Typo.serifRow)
                    .foregroundStyle(Theme.ink)
                Text(compactPath(command.path))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(command.path)
            }
            Spacer(minLength: Theme.Space.sm)
            NavigationLink {
                FileEditorView(title: command.name, path: command.path, onChange: onChange)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(width: 26, height: 26)
                    .background(Theme.divider)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Edit \(command.name)")
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(hovering: hovering)
        .onHover { hovering = $0 }
        .motion(Theme.Motion.quick, value: hovering)
    }
}
