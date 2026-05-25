import SwiftUI

/// Custom horizontal pager. Exposes:
/// - `selection`: the committed integer page index.
/// - `progress`: the *fractional* page position (live during drag), used by
///   the top nav to drive its expand/contract interpolation.
/// - `\.gesturePhase` (via environment): set when the first significant
///   motion of a drag locks it to horizontal or vertical. Pages use this
///   to disable their ScrollView (when horizontal) and to suppress card
///   taps (when not idle).
///
/// Pages are passed as an array of `AnyView`.
struct TayaPager: View {
    let pages: [AnyView]
    @Binding var selection: Int
    @Binding var progress: Double

    @State private var dragOffset: CGFloat = 0
    @State private var phase: GesturePhase = .idle

    var body: some View {
        GeometryReader { geom in
            let pageWidth = geom.size.width
            HStack(spacing: 0) {
                ForEach(pages.indices, id: \.self) { i in
                    pages[i]
                        .frame(width: pageWidth, height: geom.size.height)
                        .clipped()
                }
            }
            .frame(width: pageWidth * CGFloat(pages.count), alignment: .leading)
            .offset(x: -CGFloat(selection) * pageWidth + dragOffset)
            .simultaneousGesture(dragGesture(pageWidth: pageWidth))
            .environment(\.gesturePhase, phase)
        }
    }

    private func dragGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let h = value.translation.width
                let v = value.translation.height

                // First significant motion of the gesture: lock to the
                // dominant axis. After that, the lock holds for the rest
                // of the drag — no flipping mid-gesture.
                if phase == .idle {
                    let dominanceMargin: CGFloat = 4
                    if abs(h) > abs(v) + dominanceMargin {
                        phase = .horizontalSwipe
                    } else if abs(v) > abs(h) + dominanceMargin {
                        phase = .verticalScroll
                    }
                }

                guard phase == .horizontalSwipe else { return }

                // Rubber-band beyond first/last page.
                var t = h
                if selection == 0 && t > 0 {
                    t *= 0.35
                } else if selection == pages.count - 1 && t < 0 {
                    t *= 0.35
                }
                dragOffset = t

                let raw = Double(selection) - Double(t / pageWidth)
                progress = max(0, min(Double(pages.count - 1), raw))
            }
            .onEnded { value in
                let wasHorizontal = phase == .horizontalSwipe
                phase = .idle

                guard wasHorizontal else {
                    withAnimation(.interpolatingSpring(stiffness: 260, damping: 28)) {
                        dragOffset = 0
                        progress = Double(selection)
                    }
                    return
                }

                let translation = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let translationThreshold = pageWidth * 0.18
                let velocityHint = predicted - translation
                let velocityThreshold = pageWidth * 0.35

                var newSelection = selection
                let goNext = translation < -translationThreshold
                    || velocityHint < -velocityThreshold
                let goPrev = translation > translationThreshold
                    || velocityHint > velocityThreshold

                if goNext {
                    newSelection = min(selection + 1, pages.count - 1)
                } else if goPrev {
                    newSelection = max(selection - 1, 0)
                }

                withAnimation(.interpolatingSpring(stiffness: 260, damping: 28)) {
                    selection = newSelection
                    dragOffset = 0
                    progress = Double(newSelection)
                }
            }
    }
}
