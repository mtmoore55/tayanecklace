import SwiftUI

// The shared layout chrome behind every content detail sheet. Three
// pieces — the top-right glass action pill, a big left-aligned title
// row, and a body slot — combined here so per-type sheets only own
// their content. Pattern is borrowed from Will's Coffee with Josephine
// screen, adapted to our gradient/glass language.

/// Top-right glass capsule that holds 0–N segmented view-mode toggles
/// followed by an ellipsis menu. Per-type variation is expressed
/// through the `modes` array and the `menu` view-builder, so callers
/// can drop a `ShareLink` straight into the menu alongside plain
/// `Button`s.
struct DetailActionPill<MenuContent: View>: View {
    struct Mode: Identifiable, Hashable {
        let id: String
        let systemImage: String
        let label: String
    }

    let modes: [Mode]
    @Binding var selectedModeID: String
    @ViewBuilder let menu: () -> MenuContent

    private let slot: CGFloat = 36

    var body: some View {
        HStack(spacing: 2) {
            ForEach(modes) { mode in
                modeButton(mode)
            }
            ellipsisMenu
        }
        .padding(4)
        .tayaGlassCard(in: Capsule(style: .continuous))
    }

    private func modeButton(_ mode: Mode) -> some View {
        let isSelected = mode.id == selectedModeID
        return Button {
            selectedModeID = mode.id
        } label: {
            Image(systemName: mode.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? Theme.onAccent : Theme.primaryText)
                .frame(width: slot, height: slot)
                .background(
                    Circle().fill(isSelected ? Theme.accent : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var ellipsisMenu: some View {
        Menu {
            menu()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .frame(width: slot, height: slot)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More actions")
    }
}

/// Wrapper every detail sheet sits inside. Owns the scroll view,
/// background, presentation modifiers, the trailing action pill, the
/// title row, and an optional subtitle. Content is composed by the
/// caller and flows directly on the surface — only Moment-list
/// sections inside the body should reach for `Card`.
struct DetailChrome<Pill: View, Leading: View, Content: View>: View {
    let title: String
    let subtitle: String?
    let pill: Pill
    let leading: Leading
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String?,
        pill: Pill,
        @ViewBuilder content: @escaping () -> Content
    ) where Leading == EmptyView {
        self.title = title
        self.subtitle = subtitle
        self.pill = pill
        self.leading = EmptyView()
        self.content = content
    }

    init(
        title: String,
        subtitle: String?,
        pill: Pill,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.pill = pill
        self.leading = leading()
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    pill
                }

                HStack(alignment: .top, spacing: 14) {
                    leading
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Theme.primaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if let subtitle {
                            Text(subtitle)
                                .font(Theme.bodyM())
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                }
                .padding(.top, 24)

                content()
                    .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
    }
}

/// Bold section header followed by raw body content. No card wrapper
/// here — that's intentional. Reach for `Card` only when the section
/// is a list of Moments.
struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.titleS())
                .foregroundStyle(Theme.primaryText)
            content()
        }
    }
}

/// Italic muted line that fills a `DetailSection` when there's nothing
/// to show ("No tasks extracted."). Matches Will's pattern of keeping
/// empty states inline rather than collapsing the section.
struct DetailEmptyText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.bodyM())
            .italic()
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// In-content link to another entity's detail. Underlined white text,
/// tappable. The detail body uses these to cite People, Places,
/// Themes, source Moments — provenance the user can follow.
struct DetailEntityLink: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.bodyL())
                .foregroundStyle(Theme.primaryText)
                .underline()
        }
        .buttonStyle(.plain)
    }
}
