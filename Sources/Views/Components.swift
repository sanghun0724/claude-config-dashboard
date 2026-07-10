import AppKit
import SwiftUI

// MARK: - Shared row chrome
//
// Vocabulary shared across section views. Section-specific rows live in each
// section's own file; the custom design layer (cards, controls) lives in
// Theme.swift / Controls.swift.

/// Empty state that teaches the interface: names the directory we scanned and
/// offers a way out, instead of a bare "No X".
struct EmptyHint: View {
    let label: String   // "skills"
    let dir: String     // e.g. "~/.claude/skills"

    var body: some View {
        ContentUnavailableView {
            Label("No \(label) yet", systemImage: "tray")
        } description: {
            Text("Nothing found in \(dir).")
        } actions: {
            Button("Reveal in Finder") {
                let expanded = (dir as NSString).expandingTildeInPath
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: expanded)])
            }
        }
    }
}

/// Empty state for a search/filter query that matched nothing — distinct from
/// `EmptyHint` (which means the directory itself is empty). Offers the same
/// way out as the search field's own clear button, but anchored where the
/// user is actually looking.
struct EmptySearchHint: View {
    let label: String   // "skills"
    @Binding var query: String

    var body: some View {
        ContentUnavailableView {
            Label("No \(label) match \u{201C}\(query)\u{201D}", systemImage: "magnifyingglass")
        } description: {
            Text("Try a different search term.")
        } actions: {
            Button("Clear search") { query = "" }
        }
    }
}

/// Inline save-result line shown at the foot of an editor (success or error).
/// One shape across every screen — same icon, same color vocabulary.
struct StatusBar: View {
    let message: String
    let isError: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(message)
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(isError ? SemanticColor.error : SemanticColor.success)
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .transition(.opacity)
    }
}

/// 200ms fade for a status message appearing/clearing; instant under Reduce Motion.
private struct StatusFade<V: Equatable>: ViewModifier {
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: value)
    }
}

extension View {
    func statusFade<V: Equatable>(value: V) -> some View {
        modifier(StatusFade(value: value))
    }
}

/// Tinted caution strip for files that write outside ~/.claude or change at runtime.
struct WarningBanner: View {
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text).lineLimit(2)
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(SemanticColor.warning)
        .padding(8)
        .background(SemanticColor.warning.opacity(0.12))
    }
}

// MARK: - Path context menu

/// Right-click actions every displayed file path should offer.
private struct PathContextMenu: ViewModifier {
    let path: String
    func body(content: Content) -> some View {
        content.contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
            }
        }
    }
}

extension View {
    func pathContextMenu(_ path: String) -> some View {
        modifier(PathContextMenu(path: path))
    }
}

// MARK: - Scaffolding new config files

/// Creates a starter file under `dir` with a collision-free name and returns its
/// path. `subfile` nests the file in a folder named after the item (skills are
/// `<name>/SKILL.md`); nil writes `<name>.md` directly. Returns nil on failure.
func createScaffold(in dir: String, baseName: String, subfile: String?, template: (String) -> String) -> String? {
    let root = (dir as NSString).expandingTildeInPath
    let fm = FileManager.default
    func container(_ name: String) -> String {
        subfile != nil ? "\(root)/\(name)" : "\(root)/\(name).md"
    }
    var name = baseName
    var counter = 2
    while fm.fileExists(atPath: container(name)) {
        name = "\(baseName)-\(counter)"
        counter += 1
    }
    do {
        let filePath: String
        if let subfile {
            try fm.createDirectory(atPath: container(name), withIntermediateDirectories: true)
            filePath = "\(container(name))/\(subfile)"
        } else {
            try fm.createDirectory(atPath: root, withIntermediateDirectories: true)
            filePath = container(name)
        }
        try template(name).write(toFile: filePath, atomically: true, encoding: .utf8)
        return filePath
    } catch {
        return nil
    }
}

func skillTemplate(_ name: String) -> String {
    """
    ---
    name: \(name)
    description: Describe what this skill does and when to use it
    ---

    Instructions for the skill go here.
    """
}

func agentTemplate(_ name: String) -> String {
    """
    ---
    name: \(name)
    description: Describe what this agent does
    ---

    System prompt for the agent goes here.
    """
}

func commandTemplate(_ name: String) -> String {
    """
    ---
    description: Describe what /\(name) does
    ---

    Command prompt goes here.
    """
}

/// Shared write-back surface contract: the Reload/Restore/Discard/Save quartet that
/// every guarded editor exposes. Conformers: SettingsStore / MCPStore / TextFileStore.
@MainActor
protocol GuardedStore: ObservableObject {
    var isStale: Bool { get }
    var canRestore: Bool { get }
    var hasChanges: Bool { get }
    var statusMessage: String? { get }
    var isError: Bool { get }
    /// Available backups, newest first — feeds the Restore menu.
    var backupList: [URL] { get }
    func load()
    func restore()
    func restore(from backup: URL)
    func save()
    func discard()
}
