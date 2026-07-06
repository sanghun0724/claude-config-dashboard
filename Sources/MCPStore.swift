import Foundation
import SwiftUI

struct MCPEdit: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var kind: String     // "stdio" | "http" | "sse"
    var command: String  // stdio
    var args: String     // stdio, space-joined
    var url: String      // http / sse

    static func == (lhs: MCPEdit, rhs: MCPEdit) -> Bool {
        lhs.name == rhs.name && lhs.kind == rhs.kind &&
        lhs.command == rhs.command && lhs.args == rhs.args && lhs.url == rhs.url
    }
}

/// Editable model for `~/.claude.json` mcpServers. This file is written by Claude Code
/// at runtime, so the stale-guard is essential; saves preserve every other key (projects,
/// history, …) and every untouched per-server field (env, headers, …).
@MainActor
final class MCPStore: ObservableObject, GuardedStore {
    @Published var servers: [MCPEdit] = []
    @Published var statusMessage: String?
    @Published var isError = false
    @Published var isStale = false
    @Published var canRestore = false

    private var root: [String: Any] = [:]
    private var originalServers: [String: Any] = [:]
    private var origServers: [MCPEdit] = []
    private var loadedHash = ""
    private let fileURL: URL
    private let guardian: WriteGuard

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.fileURL = home.appending(path: ".claude.json")
        let claude = home.appending(path: ".claude")
        self.guardian = WriteGuard(fileURL: fileURL, backupDir: claude.appending(path: "backups"))
        load()
    }

    var hasChanges: Bool { servers != origServers }

    func load() {
        isStale = false
        isError = false
        statusMessage = nil
        guard let data = try? Data(contentsOf: fileURL.resolvingSymlinksInPath()),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            isError = true
            statusMessage = String(localized: "~/.claude.json not found or invalid")
            return
        }
        root = dict
        loadedHash = WriteGuard.hash(data)
        originalServers = dict["mcpServers"] as? [String: Any] ?? [:]
        servers = originalServers.map { name, value in
            let cfg = value as? [String: Any] ?? [:]
            if let url = cfg["url"] as? String {
                return MCPEdit(name: name, kind: (cfg["type"] as? String) ?? "http",
                               command: "", args: "", url: url)
            }
            let args = (cfg["args"] as? [String] ?? []).joined(separator: " ")
            return MCPEdit(name: name, kind: "stdio",
                           command: (cfg["command"] as? String) ?? "", args: args, url: "")
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        origServers = servers
        canRestore = !guardian.backups().isEmpty
    }

    func add() {
        servers.append(MCPEdit(name: "new-server", kind: "stdio", command: "", args: "", url: ""))
    }

    func remove(at offsets: IndexSet) {
        servers.remove(atOffsets: offsets)
    }

    func remove(id: UUID) {
        servers.removeAll { $0.id == id }
    }

    func discard() {
        servers = origServers
        isError = false
        statusMessage = nil
    }

    func save() {
        isError = false
        statusMessage = nil
        let names = servers.map { $0.name.trimmingCharacters(in: .whitespaces) }
        if names.contains(where: \.isEmpty) { fail(String(localized: "Empty server name not allowed")); return }
        if Set(names).count != names.count { fail(String(localized: "Duplicate server name not allowed")); return }

        var rebuilt: [String: Any] = [:]
        for e in servers {
            // preserve untouched per-server keys (env, headers, …)
            var sub = originalServers[e.name] as? [String: Any] ?? [:]
            if e.kind == "stdio" {
                sub["command"] = e.command
                sub["args"] = e.args.split(separator: " ").map(String.init)
                sub["url"] = nil
                sub["type"] = nil
            } else {
                sub["url"] = e.url
                sub["type"] = e.kind
                sub["command"] = nil
                sub["args"] = nil
            }
            rebuilt[e.name] = sub
        }
        var merged = root
        merged["mcpServers"] = rebuilt
        // Compact (no pretty/sorted) to match ~/.claude.json's runtime style.
        guard let data = try? JSONSerialization.data(withJSONObject: merged, options: [.withoutEscapingSlashes]) else {
            fail(String(localized: "Serialization failed"))
            return
        }
        do {
            try guardian.commit(data, expectedHash: loadedHash)
            root = merged
            originalServers = rebuilt
            loadedHash = WriteGuard.hash(data)
            origServers = servers
            canRestore = true
            statusMessage = String(localized: "Saved — backup created.")
        } catch let error as WriteGuardError where error == .staleFile {
            isStale = true
            fail(error.localizedDescription)
        } catch {
            fail(error.localizedDescription)
        }
    }

    func restore() {
        do {
            try guardian.restoreLatest(expectedHash: loadedHash)
            load()
            statusMessage = String(localized: "Restored from latest backup.")
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func fail(_ message: String) {
        isError = true
        statusMessage = message
    }
}
