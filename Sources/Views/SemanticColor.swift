import SwiftUI

/// Central state-color vocabulary. Delegates to the warm-harmonized `Theme` tokens so
/// status colors sit on the greige canvas instead of clashing system primaries. Kept as
/// a thin alias (stable API) — call sites are unchanged. Never load-bearing alone:
/// always paired with an SF Symbol/text at the call site.
enum SemanticColor {
    /// External symlink / runtime-volatile cautions.
    static let warning = Theme.warning
    /// Save / restore succeeded.
    static let success = Theme.success
    /// Save failure, destructive actions.
    static let error = Theme.error
}
