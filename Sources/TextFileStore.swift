import Foundation
import SwiftUI

/// Live editor for a single text file (markdown skill/agent/command bodies),
/// guarded by WriteGuard: backup-first, atomic write, stale-guard, restore.
@MainActor
final class TextFileStore: ObservableObject, GuardedStore {
    @Published var text = ""
    @Published var statusMessage: String?
    @Published var isError = false
    @Published var isStale = false
    @Published var canRestore = false

    private var loadedHash = ""
    private var origText = ""
    private let fileURL: URL
    private let guardian: WriteGuard

    init(path: String) {
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        self.fileURL = url
        // Backups live under ~/.claude/backups even for symlinked external files,
        // so we never write extra files into an external config repo.
        let claude = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude")
        self.guardian = WriteGuard(fileURL: url, backupDir: claude.appending(path: "backups"))
        load()
    }

    var hasChanges: Bool { text != origText }

    func load() {
        isStale = false
        isError = false
        statusMessage = nil
        guard let data = try? Data(contentsOf: fileURL) else {
            isError = true
            statusMessage = String(localized: "File not readable")
            return
        }
        text = String(decoding: data, as: UTF8.self)
        origText = text
        loadedHash = WriteGuard.hash(data)
        canRestore = !guardian.backups().isEmpty
    }

    func discard() {
        text = origText
        isError = false
        statusMessage = nil
    }

    func save() {
        isError = false
        statusMessage = nil
        do {
            try guardian.commit(Data(text.utf8), expectedHash: loadedHash)
            origText = text
            loadedHash = WriteGuard.hash(Data(text.utf8))
            canRestore = true
            statusMessage = String(localized: "Saved — backup created.")
        } catch let error as WriteGuardError where error == .staleFile {
            isStale = true
            fail(error.localizedDescription)
        } catch {
            fail(error.localizedDescription)
        }
    }

    /// Back up then delete the file. Returns true on success.
    func delete() -> Bool {
        do {
            try guardian.deleteWithBackup()
            return true
        } catch {
            fail(error.localizedDescription)
            return false
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
