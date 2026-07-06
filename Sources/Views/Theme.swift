import AppKit
import SwiftUI

/// Warm-minimal design system for the crafted-native shell — the "서재" (library)
/// direction from the Claude Design exploration (Claude Config Dashboard.dc.html,
/// Turn 2). Native window/toolbar are kept; everything inside is custom. Reading
/// surfaces are paper on a warm canvas, headings speak in a serif voice, metadata
/// in mono. Palette matches the design tokens exactly, light and dark.
enum Theme {
    // MARK: Surfaces (design: --canvas / --sidebar / --paper / --card)
    /// App canvas — warm greige (light) / warm near-black (dark).
    static let bg = Color(light: .hex(0xEFEBE2), dark: .hex(0x211E1A))
    /// Content / reading surface — paper, one step lighter than the canvas.
    static let surface = Color(light: .hex(0xFBF9F4), dark: .hex(0x28251F))
    /// Card surface — sits on paper (gallery cards, path boxes, command bar).
    static let card = Color(light: .hex(0xFFFDF9), dark: .hex(0x302C26))
    /// Card surface when hovered — one step lifted.
    static let surfaceHover = Color(light: .hex(0xFFFFFF), dark: .hex(0x363028))
    /// Sidebar / secondary panel surface.
    static let panel = Color(light: .hex(0xEAE5DB), dark: .hex(0x1A1815))

    // MARK: Ink (design: --ink / --ink2 / --ink3)
    static let ink = Color(light: .hex(0x221F1A), dark: .hex(0xEEE8DC))
    static let inkSecondary = Color(light: .hex(0x6B6355), dark: .hex(0xA9A08E))
    static let inkTertiary = Color(light: .hex(0x9A9082), dark: .hex(0x7B7365))

    // MARK: Accent (design: --accent / --accent2 / --accent-soft)
    static let accent = Color(light: .hex(0xBC5B39), dark: .hex(0xD97757))
    /// Deeper clay for emphasized text and hovers (lighter in dark mode).
    static let accentStrong = Color(light: .hex(0xA34829), dark: .hex(0xE4926F))
    /// Accent wash for selection backgrounds.
    static let accentSoft = Color(light: .hex(0xF3DFD3), dark: .hex(0x3B2820))

    // MARK: Lines (design: --line / --line2)
    static let border = Color(light: .hex(0xE3DCCF), dark: .hex(0x39342D))
    static let divider = Color(light: .hex(0xEDE8DD), dark: .hex(0x332F28))

    /// Warm shadow — never pure black, so elevation reads as paper, not ink.
    static let shadow = Color(light: .hex(0x3C2D1E), dark: .hex(0x000000))

    // MARK: Semantic (design: --safe / --warn triads; error stays warm brick)
    /// Caution — external symlink / runtime-volatile. Warm amber.
    static let warning = Color(light: .hex(0x9C6C25), dark: .hex(0xC89A55))
    static let warningSoft = Color(light: .hex(0xF1E5CA), dark: .hex(0x352C1B))
    static let warningInk = Color(light: .hex(0x7A5417), dark: .hex(0xD9B276))
    /// Success — save / restore / backup badge. Warm sage.
    static let success = Color(light: .hex(0x5E7350), dark: .hex(0x8FA47E))
    static let successSoft = Color(light: .hex(0xE4EBDC), dark: .hex(0x2A3125))
    static let successInk = Color(light: .hex(0x465737), dark: .hex(0xAEC09E))
    /// Error — save failure / destructive. Warm brick.
    static let error = Color(light: .hex(0xB0472F), dark: .hex(0xD66A4F))

    // MARK: Scale
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
    enum Radius {
        static let sm: CGFloat = 7
        static let md: CGFloat = 11
        static let lg: CGFloat = 16
    }

    // MARK: Dimensions
    enum Dim {
        static let sidebarWidth: CGFloat = 240
        static let indexWidth: CGFloat = 280
        static let topBarHeight: CGFloat = 48
        static let rowMinHeight: CGFloat = 32
    }

    // MARK: Typography (fixed crafted scale — not Dynamic Type fluid)
    // Serif = New York (system .serif): the reading voice for names, headings, prose.
    enum Typo {
        static let title = Font.system(size: 17, weight: .semibold)
        static let heading = Font.system(size: 14, weight: .semibold)
        static let body = Font.system(size: 13, weight: .regular)
        static let label = Font.system(size: 12, weight: .medium)
        static let caption = Font.system(size: 11, weight: .regular)
        static let mono = Font.system(size: 12, design: .monospaced)

        /// Detail headline (skill name in the reading pane).
        static let serifDisplay = Font.system(size: 28, weight: .regular, design: .serif)
        /// Section header ("Skills") and card titles.
        static let serifTitle = Font.system(size: 19, weight: .regular, design: .serif)
        /// Reading prose (long description) and finding titles.
        static let serifBody = Font.system(size: 16, weight: .regular, design: .serif)
        /// Index row names.
        static let serifRow = Font.system(size: 15, weight: .regular, design: .serif)
    }

    // MARK: Motion
    enum Motion {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeOut(duration: 0.2)
    }
}

// MARK: - Reduce-motion aware animation

private struct MotionAware<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Animate `value` with `animation`, but instantly under Reduce Motion.
    func motion<V: Equatable>(_ animation: Animation = Theme.Motion.standard, value: V) -> some View {
        modifier(MotionAware(animation: animation, value: value))
    }
}

// MARK: - Dynamic + hex color helpers

extension Color {
    /// Light/dark dynamic color resolved by the system appearance — no asset catalog.
    init(light: Color, dark: Color) {
        self = Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
    }

    static func hex(_ value: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }
}

// MARK: - Card surface

/// Paper card with continuous-corner squircle, hairline warm border, and warm
/// elevation that lifts on hover. The core building block of the content layer.
struct CardSurface: ViewModifier {
    var hovering: Bool = false
    func body(content: Content) -> some View {
        content
            .background(hovering ? Theme.surfaceHover : Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
            .shadow(
                color: Theme.shadow.opacity(hovering ? 0.13 : 0.06),
                radius: hovering ? 11 : 5,
                x: 0,
                y: hovering ? 5 : 2
            )
    }
}

extension View {
    func cardSurface(hovering: Bool = false) -> some View {
        modifier(CardSurface(hovering: hovering))
    }
}

// MARK: - Search field

/// Warm inline filter field — replaces `.searchable` so the look matches the canvas.
struct SearchField: View {
    let prompt: String
    @Binding var text: String
    /// Optional external focus binding (e.g. a ⌘K shortcut in the caller). Existing
    /// call sites are unaffected since this defaults to no binding.
    var focus: FocusState<Bool>.Binding? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkTertiary)
            textField
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkTertiary)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var textField: some View {
        let field = TextField(prompt, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(Theme.ink)
        if let focus {
            field.focused(focus)
        } else {
            field
        }
    }
}

/// Just the meaningful tail (parent/file) of a path — the full path is clutter per row.
func compactPath(_ path: String) -> String {
    let url = URL(fileURLWithPath: path)
    let parent = url.deletingLastPathComponent().lastPathComponent
    return parent.isEmpty ? url.lastPathComponent : "\(parent)/\(url.lastPathComponent)"
}

// MARK: - Chip

/// Small mono tag for metadata (allowed tools, level, model, kind, scope).
/// Design: mono on --line2 with a --line hairline; accent tone for scope emphasis.
struct Chip: View {
    let text: String
    var tone: Tone = .neutral

    enum Tone { case neutral, accent }

    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(tone == .accent ? Theme.accentStrong : Theme.inkSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tone == .accent ? Theme.accentSoft : Theme.divider)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(tone == .accent ? .clear : Theme.border, lineWidth: 1)
            )
    }
}

// MARK: - Kicker

/// Mono uppercase tracking label — the small voice above headings and groups
/// (design: 10–11px mono, letter-spacing .14em, --ink3).
struct Kicker: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .kerning(1.4)
            .foregroundStyle(Theme.inkTertiary)
    }
}

/// Short relative timestamp ("2분 전") for backup badges and updated metadata.
func relativeTime(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: Date())
}
