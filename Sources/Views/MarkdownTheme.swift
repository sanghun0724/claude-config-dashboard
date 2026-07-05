import SwiftUI

/// Typography constants derived from the editor research:
/// body 16pt, line-height ~1.5, measure capped near 66ch and centered.
enum MarkdownTheme {
    static let bodySize: CGFloat = 16
    static let codeSize: CGFloat = 14
    /// Extra gap between lines. SwiftUI lineSpacing is additive, so half the
    /// font size lands the effective line-height near 1.5×.
    static let lineSpacing: CGFloat = bodySize * 0.5
    static let paragraphSpacing: CGFloat = bodySize * 0.9
    /// ~66ch measure for SF Pro at 16pt (avg glyph ≈ 8.7pt).
    static let measure: CGFloat = 580

    static func headingSize(_ level: Int) -> CGFloat {
        switch level {
        case 1: return 28
        case 2: return 23
        case 3: return 19
        default: return 17
        }
    }
}
