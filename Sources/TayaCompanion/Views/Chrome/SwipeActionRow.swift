import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

    /// Fraction of the row width past which a swipe commits the action.
    private let commitFraction: CGFloat = 0.5
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
    /// Fixed natural width of the action chip. The chip always renders at
    /// this width; a mask reveals it progressively as the row slides, à
    /// la iOS native swipe actions. Avoids the per-character text wrap
    /// you get when the chip itself dynamically narrows.
    private let chipWidth: CGFloat = 76

    func body(content: Content) -> some View {
        // ZStack with the action well underneath and the row offset on
        // top — clipped to the row's natural frame so the row content
        // can't bleed past the Card edge as it translates.
        let stack = ZStack(alignment: .leading) {
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

        return stack.modifier(SwipePanRecognizerModifier(
            onChanged: handlePanChanged,
            onEnded: handlePanEnded,
            onCancelled: handlePanCancelled
        ))
    }

    // MARK: - Pan handling

    private func handlePanChanged(_ dx: CGFloat) {
        if dx < 0 && trailing.isEmpty { return }
        if dx > 0 && leading.isEmpty { return }
        let commitDistance = rowWidth * commitFraction
        if abs(dx) <= commitDistance {
            offset = dx
        } else {
            let excess = abs(dx) - commitDistance
            let signed = (dx < 0 ? -1.0 : 1.0) * (commitDistance + excess * pastThresholdResistance)
            offset = signed
        }
    }

    private func handlePanEnded(_ dx: CGFloat) {
        let commitDistance = rowWidth * commitFraction
        if dx < -commitDistance, let action = trailing.first {
            fire(action)
        } else if dx > commitDistance, let action = leading.first {
            fire(action)
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                offset = 0
            }
        }
    }

    private func handlePanCancelled() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            offset = 0
        }
    }

    // MARK: - Action well

    @ViewBuilder
    private var actionWell: some View {
        // The chip only renders past a 0.5pt threshold so the row at
        // rest doesn't carry an invisible chip frame. The chip itself
        // is fixed-width; a trailing-aligned rectangle mask reveals it
        // progressively as the row slides.
        if offset < -0.5, let action = trailing.first {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                actionChip(action)
                    .frame(width: chipWidth)
                    .padding(.trailing, chipEdgeInset)
            }
            .mask(
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle().frame(width: abs(offset))
                }
            )
        } else if offset > 0.5, let action = leading.first {
            HStack(spacing: 0) {
                actionChip(action)
                    .frame(width: chipWidth)
                    .padding(.leading, chipEdgeInset)
                Spacer(minLength: 0)
            }
            .mask(
                HStack(spacing: 0) {
                    Rectangle().frame(width: offset)
                    Spacer(minLength: 0)
                }
            )
        }
    }

    private func actionChip(_ action: SwipeAction) -> some View {
        VStack(spacing: 4) {
            Image(systemName: action.systemImage)
                .font(.system(size: 18, weight: .semibold))
            Text(action.label)
                .font(Theme.caption().weight(.semibold))
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: chipCornerRadius, style: .continuous)
                .fill(action.tint)
        )
        .padding(.vertical, chipVerticalInset)
        .accessibilityElement()
        .accessibilityLabel(action.label)
    }

    // MARK: - Commit

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

/// Bridges a UIKit `UIPanGestureRecognizer` (subclassed to fail on
/// vertical motion) into SwiftUI as a first-class `Gesture`. iOS adopts
/// it directly via `.gesture(...)`; macOS falls back to a plain
/// `DragGesture` (good enough for previews — there's no UIScrollView to
/// coordinate with on AppKit).
private struct SwipePanRecognizerModifier: ViewModifier {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void
    let onCancelled: () -> Void

    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content.gesture(
            HorizontalPanGesture(
                onChanged: onChanged,
                onEnded: onEnded,
                onCancelled: onCancelled
            )
        )
        #else
        content.gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onChanged { value in onChanged(value.translation.width) }
                .onEnded { value in onEnded(value.translation.width) }
        )
        #endif
    }
}

#if canImport(UIKit)

/// Wraps `HorizontalPanGestureRecognizer` as a SwiftUI gesture. The
/// recognizer is attached to the view's underlying UIKit host, which
/// means it lives in the responder chain (unlike a `.background`-hosted
/// catcher) and can fire on touches that hit child buttons. The
/// recognizer's self-failure on vertical motion lets the outer
/// `UIScrollView`'s pan take over cleanly for scrolling.
private struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat) -> Void
    var onCancelled: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> HorizontalPanGestureRecognizer {
        let recognizer = HorizontalPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        // Crucial: keep child taps working. Without this, swiping that
        // doesn't commit cancels the tap, so quick taps after a partial
        // drag would be eaten.
        recognizer.cancelsTouchesInView = false
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: HorizontalPanGestureRecognizer, context: Context) {
        let dx = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed:
            onChanged(dx)
        case .ended:
            onEnded(dx)
        case .cancelled, .failed:
            onCancelled()
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Coexist with the outer ScrollView's pan; we self-fail on
            // vertical, so we won't fight it for scrolling.
            true
        }
    }
}

/// Subclasses `UIPanGestureRecognizer` to fail itself on the first
/// detection of vertical motion. That signals to UIKit's gesture
/// arbitration that the outer `UIScrollView`'s pan should take over,
/// rather than being held back by a sibling recognizer claiming the
/// touch sequence.
private final class HorizontalPanGestureRecognizer: UIPanGestureRecognizer {
    private var didCommitDirection = false
    /// Minimum motion before we commit to "horizontal" or "vertical."
    /// Smaller values catch quick flicks; larger values feel sluggish.
    private let directionThreshold: CGFloat = 8

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard !didCommitDirection else { return }
        let t = translation(in: view)
        guard abs(t.x) > directionThreshold || abs(t.y) > directionThreshold else { return }
        didCommitDirection = true
        if abs(t.y) >= abs(t.x) {
            // Vertical wins → fail so the parent scroller takes over.
            state = .failed
        }
    }

    override func reset() {
        super.reset()
        didCommitDirection = false
    }
}

#endif
