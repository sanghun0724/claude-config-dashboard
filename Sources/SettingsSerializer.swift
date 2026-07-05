import Foundation

/// Pure, testable settings.json transform.
/// Defense #3 (preserve-unknown): mutate ONLY permissions.{allow,ask,deny};
/// every other key — top-level and inside `permissions` — is carried through untouched.
enum SettingsSerializer {
    static func apply(root: [String: Any], allow: [String], ask: [String], deny: [String]) -> [String: Any] {
        var dict = root
        var perms = dict["permissions"] as? [String: Any] ?? [:]
        perms["allow"] = allow
        perms["ask"] = ask
        perms["deny"] = deny
        dict["permissions"] = perms
        return dict
    }

    /// Deterministic, valid JSON. `.sortedKeys` keeps diffs stable across writes.
    static func serialize(_ dict: [String: Any]) throws -> Data {
        try JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }
}
