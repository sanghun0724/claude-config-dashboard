import SwiftUI

/// Skills as a 서재 (reading room) — the flagship screen of the design. Default is
/// reading: an index column plus a serif reading pane. One toggle switches to a
/// gallery of tactile cards. Both views share one selection; editing always goes
/// through the guarded file editor.
struct SkillsView: View {
    let skills: [Skill]
    var dir: String = "~/.claude/skills"
    var onChange: () -> Void = {}

    @State private var query = ""
    @State private var viewMode: ViewMode = .reading
    @State private var selectedPath: String?
    @FocusState private var searchFocused: Bool

    enum ViewMode: String, CaseIterable {
        case reading = "읽기", gallery = "갤러리"
    }

    private var filtered: [Skill] {
        guard !query.isEmpty else { return skills }
        return skills.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query)
        }
    }

    private var selected: Skill? {
        filtered.first { $0.path == selectedPath } ?? filtered.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Group {
                    if skills.isEmpty {
                        EmptyHint(label: "skills", dir: dir)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewMode == .reading {
                        readingRoom
                            .transition(.opacity)
                    } else {
                        gallery
                            .transition(.opacity)
                    }
                }
                .motion(Theme.Motion.standard, value: viewMode)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.surface)
        }
        .background {
            Button("") { searchFocused = true }
                .keyboardShortcut("k", modifiers: .command)
                .hidden()
        }
    }

    // MARK: - Header (serif title · count · view toggle)

    private var header: some View {
        HStack(spacing: Theme.Space.md) {
            Text("Skills")
                .font(Theme.Typo.serifTitle)
                .foregroundStyle(Theme.ink)
            Text("\(skills.count) active")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(Theme.inkTertiary)
            Spacer()
            SearchField(prompt: "스킬 검색", text: $query, focus: $searchFocused)
                .frame(width: 200)
            SegmentedControl(
                selection: $viewMode,
                options: ViewMode.allCases.map { (value: $0, label: $0.rawValue) }
            )
            .frame(width: 140)
        }
        .padding(.horizontal, Theme.Space.xl)
        .frame(height: Theme.Dim.topBarHeight + 8)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    // MARK: - 읽기 — index + reading pane

    private var readingRoom: some View {
        HStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { skill in
                        IndexRow(skill: skill, isSelected: skill.path == selected?.path) {
                            selectedPath = skill.path
                        }
                    }
                }
                .padding(.vertical, Theme.Space.md)
            }
            .frame(width: Theme.Dim.indexWidth)
            .overlay(alignment: .trailing) { Rectangle().fill(Theme.border).frame(width: 1) }

            if let skill = selected {
                ReadingPane(skill: skill, onChange: onChange)
            } else {
                EmptySearchHint(label: "skills", query: $query)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - 갤러리 — card grid

    @ViewBuilder
    private var gallery: some View {
        if filtered.isEmpty {
            EmptySearchHint(label: "skills", query: $query)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.lg), count: 3),
                    spacing: Theme.Space.lg
                ) {
                    ForEach(filtered) { skill in
                        GalleryCard(skill: skill, isSelected: skill.path == selected?.path) {
                            selectedPath = skill.path
                        } onOpen: {
                            selectedPath = skill.path
                            viewMode = .reading
                        }
                    }
                }
                .padding(Theme.Space.xl)
            }
        }
    }
}

// MARK: - Index row

private struct IndexRow: View {
    let skill: Skill
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(skill.name)
                    .font(Theme.Typo.serifRow)
                    .foregroundStyle(isSelected ? Theme.accentStrong : Theme.ink)
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering ? Theme.divider : .clear)
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.accent)
                        .frame(width: 2)
                        .padding(.vertical, 10)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.divider).frame(height: 1).padding(.horizontal, Theme.Space.lg)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .motion(Theme.Motion.quick, value: hovering)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Reading pane

private struct ReadingPane: View {
    let skill: Skill
    var onChange: () -> Void

    private var isExternal: Bool { !skill.path.contains("/.claude/") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Skill · \(isExternal ? "External" : "Personal")")
                    .padding(.bottom, 14)

                Text(skill.name)
                    .font(Theme.Typo.serifDisplay)
                    .foregroundStyle(Theme.ink)
                    .padding(.bottom, 12)

                metaRow
                    .padding(.bottom, 24)

                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(Theme.Typo.serifBody)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(7)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 28)
                }

                if !skill.tools.isEmpty {
                    Kicker(text: "Allowed tools")
                        .padding(.bottom, 11)
                    FlowChips(items: skill.tools)
                        .padding(.bottom, 28)
                }

                Text(skill.path)
                    .font(Theme.Typo.mono)
                    .foregroundStyle(Theme.inkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
                    .help(skill.path)
                    .padding(.bottom, 20)

                Rectangle().fill(Theme.border).frame(height: 1)
                    .padding(.bottom, 18)

                HStack(spacing: 14) {
                    NavigationLink {
                        FileEditorView(title: skill.name, path: skill.path, onChange: onChange)
                    } label: {
                        Text("편집")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.accentStrong)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                    .strokeBorder(Theme.accent, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 7) {
                        Circle().fill(Theme.success).frame(width: 7, height: 7)
                        Text("읽기 전용 미리보기 · 편집 시 자동 백업")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.successInk)
                    }
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .padding(.horizontal, 44)
            .padding(.vertical, 36)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metaRow: some View {
        let hasLevel = skill.level != nil
        let hasHint = skill.argumentHint?.isEmpty == false
        let hasModified = skill.modified != nil
        return HStack(spacing: 8) {
            if !skill.tools.isEmpty {
                Text("\(skill.tools.count)개 도구")
                if hasModified || hasLevel || hasHint {
                    Text("·").foregroundStyle(Theme.inkTertiary)
                }
            }
            if let modified = skill.modified {
                Text("업데이트 \(relativeTime(modified))")
                if hasLevel || hasHint {
                    Text("·").foregroundStyle(Theme.inkTertiary)
                }
            }
            if let level = skill.level {
                Chip(text: "L\(level)", tone: .accent)
            }
            if let hint = skill.argumentHint, !hint.isEmpty {
                Chip(text: hint)
            }
        }
        .font(.system(size: 12.5, design: .monospaced))
        .foregroundStyle(Theme.inkSecondary)
    }
}

/// Wrapping row of mono chips (allowed tools).
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { Chip(text: $0) }
        }
    }
}

/// Minimal left-aligned wrapping layout for chip rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (index, origin) in arrange(proposal: proposal, subviews: subviews).origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            width = max(width, x + size.width)
            x += size.width + spacing
        }
        return (origins, CGSize(width: width, height: y + rowHeight))
    }
}

// MARK: - Gallery card

private struct GalleryCard: View {
    let skill: Skill
    let isSelected: Bool
    let action: () -> Void
    var onOpen: () -> Void = {}
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 8) {
                    Text(skill.name)
                        .font(.system(size: 17, design: .serif))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if isSelected {
                        Circle().fill(Theme.accent).frame(width: 8, height: 8)
                            .padding(.top, 5)
                    }
                }
                Text(skill.description)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Chip(
                        text: skill.path.contains("/.claude/") ? "Personal" : "External",
                        tone: skill.path.contains("/.claude/") ? .neutral : .accent
                    )
                    if !skill.tools.isEmpty {
                        Text("\(skill.tools.count) tools")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                    Spacer()
                    if let modified = skill.modified {
                        Text(relativeTime(modified))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 15)
            .frame(minHeight: 150, alignment: .top)
            .background(hovering ? Theme.surfaceHover : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: isSelected ? 1.5 : 0)
            )
            .shadow(
                color: Theme.shadow.opacity(hovering || isSelected ? 0.12 : 0.06),
                radius: hovering || isSelected ? 10 : 5,
                y: hovering || isSelected ? 5 : 2
            )
            .offset(y: isSelected ? -2 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .motion(Theme.Motion.quick, value: hovering)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .simultaneousGesture(TapGesture(count: 2).onEnded(onOpen))
    }
}
