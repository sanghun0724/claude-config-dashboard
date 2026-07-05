import AppKit
import SwiftUI

/// Applies live-preview display attributes to a markdown text storage.
/// Only attributes change — never the characters — so the saved file is byte-exact.
///
/// Rule: the paragraph containing the cursor stays raw (markers visible); other
/// lines get heading/emphasis styling and their markup markers are visually
/// collapsed (0.01pt + clear), the pragmatic AppKit stand-in for zero-width.
enum MarkdownStyler {
    static let baseFont = NSFont.systemFont(ofSize: MarkdownTheme.bodySize)
    private static let codeFont = NSFont.monospacedSystemFont(ofSize: MarkdownTheme.codeSize, weight: .regular)
    private static let hiddenFont = NSFont.systemFont(ofSize: 0.01)

    private static let heading = try! NSRegularExpression(pattern: "^(#{1,6})[ \\t]+(.*)$")
    private static let bold = try! NSRegularExpression(pattern: "(\\*\\*|__)(.+?)\\1")
    private static let italic = try! NSRegularExpression(pattern: "(?<![\\*_])([\\*_])([^\\*_]+)\\1(?![\\*_])")
    private static let code = try! NSRegularExpression(pattern: "`([^`]+)`")

    static func apply(to storage: NSTextStorage, selected: NSRange) {
        let ns = storage.string as NSString
        restyleLines(storage, ns, in: NSRange(location: 0, length: ns.length), selected: selected)
    }

    /// Restyles only the lines overlapping `range` — used to touch just the one or
    /// two paragraphs whose raw/collapsed state actually changed on a selection move,
    /// so every other line's attributes (and therefore its layout) stays untouched.
    /// Resetting the *whole* document on every cursor move was what dragged the
    /// scroll position: any paragraph toggling between raw and collapsed markup
    /// changes height, and invalidating layout for the entire text on every such
    /// toggle made the viewport visibly jump.
    static func restyleLines(_ storage: NSTextStorage, in range: NSRange, selected: NSRange) {
        let ns = storage.string as NSString
        restyleLines(storage, ns, in: range, selected: selected)
    }

    private static func restyleLines(_ storage: NSTextStorage, _ ns: NSString, in range: NSRange, selected: NSRange) {
        let active = ns.paragraphRange(for: NSRange(location: min(selected.location, ns.length), length: 0))
        let frontmatter = frontmatterRange(ns)

        storage.beginEditing()
        storage.setAttributes([
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph()
        ], range: range)

        ns.enumerateSubstrings(in: range, options: .byLines) { _, lineRange, _, _ in
            if let frontmatter, lineRange.location < frontmatter.length {
                styleFrontmatterLine(storage, ns, lineRange)
            } else {
                let raw = lineRange.intersection(active) != nil
                styleLine(storage, ns, lineRange, hide: !raw)
            }
        }
        storage.endEditing()
    }

    /// The `---`-delimited block at the very top of the document, if present —
    /// its extent in document coordinates (from location 0 through the closing `---` line).
    private static func frontmatterRange(_ ns: NSString) -> NSRange? {
        guard ns.length > 0 else { return nil }
        let firstLine = ns.paragraphRange(for: NSRange(location: 0, length: 0))
        guard ns.substring(with: firstLine).trimmingCharacters(in: .whitespacesAndNewlines) == "---" else { return nil }

        var cursor = NSMaxRange(firstLine)
        while cursor < ns.length {
            let lineRange = ns.paragraphRange(for: NSRange(location: cursor, length: 0))
            if ns.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                return NSRange(location: 0, length: NSMaxRange(lineRange))
            }
            cursor = NSMaxRange(lineRange)
        }
        return nil
    }

    /// Frontmatter reads as settings, not prose: a panel tint, bold mono keys,
    /// secondary-ink values, dimmed `---` delimiters.
    private static func styleFrontmatterLine(_ storage: NSTextStorage, _ ns: NSString, _ lineRange: NSRange) {
        storage.addAttribute(.backgroundColor, value: NSColor(Theme.panel), range: lineRange)

        let line = ns.substring(with: lineRange)
        guard line.trimmingCharacters(in: .whitespacesAndNewlines) != "---" else {
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: lineRange)
            return
        }
        let lineNS = line as NSString
        let colon = lineNS.range(of: ":")
        guard colon.location != NSNotFound else { return }
        let keyLength = colon.location + 1
        let keyRange = abs(NSRange(location: 0, length: keyLength), in: lineRange)
        let valueRange = abs(NSRange(location: keyLength, length: lineNS.length - keyLength), in: lineRange)

        storage.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: MarkdownTheme.codeSize, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ], range: keyRange)
        storage.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: MarkdownTheme.codeSize, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ], range: valueRange)
    }

    private static func paragraph() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = MarkdownTheme.lineSpacing
        p.paragraphSpacing = MarkdownTheme.bodySize * 0.4
        return p
    }

    private static func hide(_ storage: NSTextStorage, _ range: NSRange) {
        storage.addAttributes([.font: hiddenFont, .foregroundColor: NSColor.clear], range: range)
    }

    private static func dim(_ storage: NSTextStorage, _ range: NSRange) {
        storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: range)
    }

    private static func styleLine(_ storage: NSTextStorage, _ ns: NSString, _ lineRange: NSRange, hide hideMarkers: Bool) {
        let line = ns.substring(with: lineRange)
        let lineNS = line as NSString
        let lineFull = NSRange(location: 0, length: lineNS.length)

        // Heading: size the body, hide/dim the leading hashes.
        if let m = heading.firstMatch(in: line, range: lineFull) {
            let level = m.range(at: 1).length
            let bodyRange = abs(m.range(at: 2), in: lineRange)
            let markerRange = abs(m.range(at: 1), in: lineRange)
            let trailing = NSRange(location: markerRange.location + markerRange.length,
                                   length: bodyRange.location - (markerRange.location + markerRange.length))
            storage.addAttribute(.font,
                value: NSFont.boldSystemFont(ofSize: MarkdownTheme.headingSize(level)),
                range: bodyRange)
            if hideMarkers {
                hide(storage, markerRange)
                hide(storage, trailing)
            } else {
                dim(storage, markerRange)
            }
            applyInline(storage, line, lineRange, hide: hideMarkers)
            return
        }

        applyInline(storage, line, lineRange, hide: hideMarkers)
    }

    /// Emphasis + inline code. Marker delimiters hidden on non-active lines.
    private static func applyInline(_ storage: NSTextStorage, _ line: String, _ lineRange: NSRange, hide hideMarkers: Bool) {
        let lineFull = NSRange(location: 0, length: (line as NSString).length)

        func walk(_ re: NSRegularExpression, _ apply: (_ inner: NSRange, _ open: NSRange, _ close: NSRange) -> Void) {
            for m in re.matches(in: line, range: lineFull) {
                let delim = m.range(at: 1)
                let inner = m.range(at: m.numberOfRanges - 1)
                let open = NSRange(location: m.range.location, length: delim.length)
                let close = NSRange(location: m.range.location + m.range.length - delim.length, length: delim.length)
                apply(abs(inner, in: lineRange), abs(open, in: lineRange), abs(close, in: lineRange))
            }
        }

        // code first (so * inside code isn't treated as emphasis is acceptable to skip; keep order simple)
        for m in code.matches(in: line, range: lineFull) {
            let inner = abs(m.range(at: 1), in: lineRange)
            let open = abs(NSRange(location: m.range.location, length: 1), in: lineRange)
            let close = abs(NSRange(location: m.range.location + m.range.length - 1, length: 1), in: lineRange)
            storage.addAttributes([.font: codeFont, .foregroundColor: NSColor.systemPink], range: inner)
            markers(storage, open, close, hide: hideMarkers)
        }

        walk(bold) { inner, open, close in
            storage.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: MarkdownTheme.bodySize), range: inner)
            markers(storage, open, close, hide: hideMarkers)
        }
        walk(italic) { inner, open, close in
            let f = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
            storage.addAttribute(.font, value: f, range: inner)
            markers(storage, open, close, hide: hideMarkers)
        }
    }

    private static func markers(_ storage: NSTextStorage, _ open: NSRange, _ close: NSRange, hide hideMarkers: Bool) {
        if hideMarkers { hide(storage, open); hide(storage, close) }
        else { dim(storage, open); dim(storage, close) }
    }

    /// Shift a line-local range into document coordinates.
    private static func abs(_ r: NSRange, in lineRange: NSRange) -> NSRange {
        NSRange(location: lineRange.location + r.location, length: r.length)
    }
}
