import SwiftUI

/// Where in the gesture lifecycle we are. Set by `TayaPager` based on the
/// dominant direction of the first significant motion. Pages read this
/// via `\.gesturePhase` to:
/// - disable their `ScrollView` when `.horizontalSwipe` (so vertical
///   scrolling doesn't compete with paging),
/// - ignore card taps when `!= .idle` (so swipes or scrolls don't
///   accidentally trigger detail sheets).
public enum GesturePhase: Equatable {
    case idle
    case horizontalSwipe
    case verticalScroll
}

private struct GesturePhaseKey: EnvironmentKey {
    static let defaultValue: GesturePhase = .idle
}

extension EnvironmentValues {
    public var gesturePhase: GesturePhase {
        get { self[GesturePhaseKey.self] }
        set { self[GesturePhaseKey.self] = newValue }
    }
}

/// Inner horizontal scrollers (carousels) register their frame here so
/// `TayaPager` can defer page-swipe gestures when the user drags inside
/// one of them. Frames are reported in `TayaPager.coordinateSpace`.
public struct InnerHorizontalCaptureKey: PreferenceKey {
    public static let defaultValue: [CGRect] = []
    public static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Marks this view as owning horizontal pan gestures. The enclosing
    /// `TayaPager` will skip its own drag handling when the user starts a
    /// horizontal drag inside the marked region.
    public func capturesHorizontalSwipe() -> some View {
        background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: InnerHorizontalCaptureKey.self,
                    value: [geo.frame(in: .named(TayaPagerCoordinateSpace))]
                )
            }
        )
    }
}

/// Named coordinate space the pager registers, so inner views can report
/// frames in a stable space the gesture can compare against.
public let TayaPagerCoordinateSpace = "TayaPager"

/// Signed distance from this page to the currently centered page, in units
/// of page width. `0` when centered, `+1` when one page-width to the right
/// of center, `-1` to the left, fractional during a swipe. Pages read this
/// to drive subtle parallax effects (e.g. the Necklace 3D hero's yaw).
private struct PagerDistanceFromActiveKey: EnvironmentKey {
    static let defaultValue: Double = 0
}

extension EnvironmentValues {
    public var pagerDistanceFromActive: Double {
        get { self[PagerDistanceFromActiveKey.self] }
        set { self[PagerDistanceFromActiveKey.self] = newValue }
    }
}
