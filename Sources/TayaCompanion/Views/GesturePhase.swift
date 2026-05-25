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
