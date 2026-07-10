import SwiftUI

// MARK: - Buttons

/// Solid clay action button (Save, primary affordances). Cream on accent; the
/// disabled state drops to a quiet line2/ink3 pill (design: "변경 없음").
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(enabled ? Color.hex(0xFBF9F4) : Theme.inkTertiary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                enabled
                    ? Theme.accent.opacity(configuration.isPressed ? 0.82 : 1)
                    : Theme.divider
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .contentShape(Rectangle())
    }
}

/// Bordered neutral button (Restore, Discard, Reload). Ink on surface.
struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typo.label)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? Theme.divider : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
            .opacity(enabled ? 1 : 0.4)
            .contentShape(Rectangle())
    }
}

/// Borderless icon button with a hover wash (reload, trash, clear).
struct IconButton: View {
    let systemName: String
    var role: ButtonRole?
    let help: String
    let action: () -> Void
    @State private var hovering = false

    init(_ systemName: String, role: ButtonRole? = nil, help: String, action: @escaping () -> Void) {
        self.systemName = systemName
        self.role = role
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .foregroundStyle(role == .destructive ? Theme.error : Theme.inkSecondary)
                .frame(width: 26, height: 26)
                .background(hovering ? Theme.divider : .clear)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
        .accessibilityLabel(help)
    }
}

// MARK: - Segmented control

/// Custom segmented picker — replaces the stock segmented `Picker` look. Pill highlight
/// on the selected segment, keyboard focus preserved via the underlying buttons.
struct SegmentedControl<T: Hashable>: View {
    @Binding var selection: T
    let options: [(value: T, label: String)]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.label)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Theme.accentStrong : Theme.inkSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm - 1, style: .continuous)
                                .fill(isSelected ? Theme.card : .clear)
                                .shadow(color: Theme.shadow.opacity(isSelected ? 0.10 : 0), radius: 2, y: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.label)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.divider)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm + 2, style: .continuous))
    }
}

// MARK: - Text field

/// Warm text field with a resting hairline border and an accent focus ring (the
/// keyboard-navigation affordance that `.textFieldStyle(.plain)` drops).
struct ThemedField: View {
    let prompt: String
    @Binding var text: String
    var mono: Bool = false
    var isSecure: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(prompt, text: $text)
            } else {
                TextField(prompt, text: $text)
            }
        }
            .textFieldStyle(.plain)
            .font(mono ? Theme.Typo.mono : Theme.Typo.body)
            .foregroundStyle(Theme.ink)
            .focused($focused)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(focused ? Theme.accent : Theme.border, lineWidth: focused ? 1.5 : 1)
            )
            .motion(Theme.Motion.quick, value: focused)
            .accessibilityLabel(prompt)
    }
}

// MARK: - Action bar

/// The shared write-back surface — the design's 안전망 save bar (2b): the safety
/// chain stays visible next to the actions, so editing never feels risky.
/// Conformers already implement `GuardedStore`.
struct ActionBar<S: GuardedStore>: View {
    @ObservedObject var store: S
    var onChange: () -> Void = {}
    @State private var chainExpanded = false
    @State private var statusVisible = false

    var body: some View {
        HStack(spacing: Theme.Space.lg) {
            HStack(spacing: 8) {
                Circle().fill(Theme.success).frame(width: 7, height: 7)
                Text("7-layer safety net")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.successInk)
            }
            .help("Backup → atomic write → drift detection → verify · DESIGN-writeback.md")
            .onHover { chainExpanded = $0 }

            if chainExpanded {
                safetyChain.transition(.opacity)
            }

            noteView

            Spacer(minLength: Theme.Space.sm)

            if store.isStale {
                Button("Reload") { store.load() }
                    .buttonStyle(GhostButtonStyle())
                    .help("Reload from disk — the file changed while this was open")
            }
            Menu {
                ForEach(Array(store.backupList.enumerated()), id: \.element) { index, backup in
                    Button(backupLabel(backup, isLatest: index == 0)) {
                        store.restore(from: backup)
                        onChange()
                    }
                }
            } label: {
                Text("Restore")
            }
            .menuStyle(.button)
            .buttonStyle(GhostButtonStyle())
            .fixedSize()
            .disabled(!store.canRestore)
            .help("Revert to a backup — pick which one")
            Button("Discard") { store.discard() }
                .buttonStyle(GhostButtonStyle())
                .disabled(!store.hasChanges)
                .help("Revert to what it was when opened")
            Button {
                store.save(); onChange()
            } label: {
                Text(store.hasChanges ? "Save" : "No changes")
                    .contentTransition(.opacity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!store.hasChanges)
            .keyboardShortcut("s", modifiers: .command)
            .motion(Theme.Motion.quick, value: store.hasChanges)
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.vertical, 10)
        .background(Theme.bg)
        .overlay(alignment: .top) { Rectangle().fill(Theme.border).frame(height: 1) }
        .motion(Theme.Motion.quick, value: chainExpanded)
        .task(id: store.statusMessage) {
            guard store.statusMessage != nil else { statusVisible = false; return }
            statusVisible = true
            try? await Task.sleep(for: .seconds(2.5))
            statusVisible = false
        }
    }

    /// Normally the safety sentence; borrows this slot for ~2.5s to surface a
    /// save/restore result instead of adding a second status row. The icon
    /// matches `StatusBar`'s vocabulary so a result reads the same everywhere.
    private var noteView: some View {
        HStack(spacing: 6) {
            if statusVisible {
                Image(systemName: store.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(store.isError ? Theme.error : Theme.successInk)
                    .transition(.opacity)
            }
            Text(statusVisible ? (store.statusMessage ?? "") : defaultNote)
                .font(.system(size: 11.5, design: .serif))
                .italic()
                .foregroundStyle(statusVisible ? (store.isError ? Theme.error : Theme.successInk) : Theme.inkTertiary)
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .motion(Theme.Motion.standard, value: statusVisible)
    }

    private var defaultNote: String {
        store.hasChanges
            ? String(localized: "Saving backs up first, then replaces atomically.")
            : String(localized: "No changes yet. Editing engages the safety net.")
    }

    private func backupLabel(_ url: URL, isLatest: Bool) -> String {
        let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
        let stamp = date.map { relativeTime($0) } ?? url.lastPathComponent
        return isLatest ? String(localized: "Latest — \(stamp)") : stamp
    }

    /// Backup → atomic write → drift detection → verify — mono, arrows dimmed.
    private var safetyChain: some View {
        HStack(spacing: 8) {
            ForEach(Array([
                String(localized: "Backup"),
                String(localized: "Atomic write"),
                String(localized: "Drift detection"),
                String(localized: "Verify")
            ].enumerated()), id: \.offset) { index, step in
                if index > 0 {
                    Text("→").foregroundStyle(Theme.border)
                }
                Text(step).foregroundStyle(Theme.inkTertiary)
            }
        }
        .font(.system(size: 11, design: .monospaced))
        .lineLimit(1)
        .fixedSize()
    }
}
