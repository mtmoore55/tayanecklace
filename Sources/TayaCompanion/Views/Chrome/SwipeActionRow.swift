import SwiftUI

/// One swipe affordance: an icon + label, a tint, and a closure. Used by
/// the `.swipeActions` modifier below to materialize the action chip that
/// reveals as the user drags a row.
struct SwipeAction: Identifiable {
    let id = UUID()
    let label: String
    let systemImage: String
    let tint: Color
    let role: ButtonRole?
    let action: () -> Void

    init(
        label: String,
        systemImage: String,
        tint: Color,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.systemImage = systemImage
        self.tint = tint
        self.role = role
        self.action = action
    }
}

extension View {
    /// Custom swipe-to-act affordance for rows that live inside the app's
    /// `ScrollView + Card` containers (where SwiftUI's native
    /// `List.swipeActions` doesn't apply). Drag past the commit threshold
    /// to fire the leading or trailing action; a short drag snaps back.
    ///
    /// Visual reference: iOS 26's `List.swipeActions` — rounded, slightly-
    /// inset action chip that tracks the drag and clips cleanly inside
    /// the row's frame so the row content can't bleed past its container.
    ///
    /// - Parameters:
    ///   - trailing: actions revealed when the row is dragged left (one
    ///     visible chip; multi-action support is out of scope for v1).
    ///   - leading: actions revealed when the row is dragged right.
    func swipeActions(
        trailing: [SwipeAction] = [],
        leading: [SwipeAction] = []
    ) -> some View {
        modifier(SwipeActionsModifier(trailing: trailing, leading: leading))
    }
}

private struct SwipeActionsModifier: ViewModifier {
    let trailing: [SwipeAction]
    let leading: [SwipeAction]

    @State private var offset: CGFloat = 0
    @State private var rowWidth: CGFloat = 0
    @State private var axisLocked: Bool = false
    @State private var isHorizontal: Bool = false

    /// Fraction of the row width past which a swipe commits the action.
    private let commitFraction: CGFloat = 0.5
    /// How far into the drag we wait before locking the gesture's axis.
    private let lockThreshold: CGFloat = 8
    /// Resistance ratio applied past the commit threshold so the row
    /// tugs against further travel instead of running flush off-screen.
    private let pastThresholdResistance: CGFloat = 0.5
    /// Vertical breathing room around the chip — keeps it a separate
    /// button rather than a full-row red wash.
    private let chipVerticalInset: CGFloat = 4
    /// Trailing/leading breathing room from the row's edge.
    private let chipEdgeInset: CGFloat = 4
    /// Corner radius of the chip itself. Tuned to read as a button
    /// nested inside the row's larger Card corner, à la iOS 26.
    private let chipCornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        // ZStack with the action well underneath and the row offset on
        // top — clipped to the row's natural frame so the row content
        // can't bleed past the Card edge as it translates.
        ZStack(alignment: .leading) {
            actionWell
            content
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { rowWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, new in rowWidth = new }
                    }
                )
                .offset(x: offset)
        }
        .clipped()
        .simultaneousGesture(dragGesture)
    }

    // MARK: - Action well

    @ViewBuilder
    private var actionWell: some View {
        // The chip only renders past a 0.5pt threshold so the row at
        // rest doesn't carry an invisible chip frame.
        if offset < -0.5, let action = trailing.first {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                actionChip(action)
                    .frame(width: max(abs(offset) - chipEdgeInset, 0))
                    .padding(.trailing, chipEdgeInset)
            }
        } else if offset > 0.5, let action = leading.first {
            HStack(spacing: 0) {
                actionChip(action)
                    .frame(width: max(offset - chipEdgeInset, 0))
                    .padding(.leading, chipEdgeInset)
                Spacer(minLength: 0)
            }
        }
    }

    private func actionChip(_ action: SwipeAction) -> some View {
        VStack(spacing: 4) {
            Image(systemName: action.systemImage)
                .font(.system(size: 18, weight: .semibold))
            Text(action.label)
                .font(Theme.caption().weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: chipCornerRadius, style: .continuous)
                .fill(action.tint)
        )
        .padding(.vertical, chipVerticalInset)
        .clipped()
        .accessibilityElement()
        .accessibilityLabel(action.label)
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height

                if !axisLocked {
                    // Wait until the motion is unambiguous before claiming
                    // horizontal — keeps vertical scrolls untouched.
                    guard abs(dx) > lockThreshold || abs(dy) > lockThreshold else { return }
                    axisLocked = true
                    isHorizontal = abs(dx) > abs(dy)
                }
                guard isHorizontal else { return }

                // Block drag in directions with no actions.
                if dx < 0 && trailing.isEmpty { return }
                if dx > 0 && leading.isEmpty { return }

                let commitDistance = rowWidth * commitFraction
                let raw = dx
                if abs(raw) <= commitDistance {
                    offset = raw
                } else {
                    let excess = abs(raw) - commitDistance
                    let signed = (raw < 0 ? -1.0 : 1.0) * (commitDistance + excess * pastThresholdResistance)
                    offset = signed
                }
            }
            .onEnded { _ in
                defer {
                    axisLocked = false
                    isHorizontal = false
                }
                guard isHorizontal else { return }

                let commitDistance = rowWidth * commitFraction
                if offset < -commitDistance, let action = trailing.first {
                    fire(action)
                } else if offset > commitDistance, let action = leading.first {
                    fire(action)
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        offset = 0
                    }
                }
            }
    }

    private func fire(_ action: SwipeAction) {
        Haptics.commit()
        // Snap the row closed so it doesn't keep its open offset under
        // the new row that takes its slot when the parent's ForEach
        // re-renders post-delete.
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            offset = 0
        }
        action.action()
    }
}
