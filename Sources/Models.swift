import Foundation

struct Skill: Identifiable {
    var id: String { path }
    let name: String
    let description: String
    let argumentHint: String?
    let level: String?
    let tools: [String]
    let modified: Date?
    let path: String
}

struct Agent: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let model: String?
    let level: String?
    let disallowedTools: String?
    let path: String
}

struct Command: Identifiable {
    let id = UUID()
    let name: String   // namespaced with ":" for commands nested in subdirectories, e.g. "git:commit"
    let kind: String   // always "file" — namespace directories are flattened, never listed themselves
    let path: String
}

struct MCPServer: Identifiable {
    let id = UUID()
    let name: String
    let detail: String   // command line or url
    let kind: String     // "stdio" | "http" | "sse" | "unknown"
}

struct HookEntry: Identifiable {
    let id = UUID()
    let event: String
    let matcher: String
    let commands: [String]
}

struct PermissionRule: Identifiable {
    let id = UUID()
    let value: String
}

struct EnvVar: Identifiable, Equatable {
    let id = UUID()
    var key: String
    var value: String

    static func == (lhs: EnvVar, rhs: EnvVar) -> Bool {
        lhs.key == rhs.key && lhs.value == rhs.value
    }
}

struct ConfigData {
    var claudeDir: String = ""
    var skills: [Skill] = []
    var agents: [Agent] = []
    var commands: [Command] = []
    var mcpServers: [MCPServer] = []
    var hooks: [HookEntry] = []
    var allow: [PermissionRule] = []
    var deny: [PermissionRule] = []
    var ask: [PermissionRule] = []
    var envVars: [EnvVar] = []
    var errors: [String] = []

    static let empty = ConfigData()
}
