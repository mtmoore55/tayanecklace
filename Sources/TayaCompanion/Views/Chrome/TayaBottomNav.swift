import SwiftUI
import TayaIntelligence

/// Bottom tab row. A single Liquid Glass capsule sits behind the
/// currently selected tab and follows `progress` continuously. The
/// pill can be tapped or dragged across the slots — during drag it
/// stretches slightly to read as a malleable glass blob — and snaps
/// to the nearest tab on release. Because `progress` is shared with
/// the page pager, dragging the pill scrubs the page content in sync.
struct TayaBottomNav: View {
    @Binding var progress: Double
    let onSelect: (AppTab) -> Void

    @State private var isDragging: Bool = false

    private let pillHeight: CGFloat = 64
    private let slotWidth: CGFloat = 76
    private let pillInset: CGFloat = 4
    private let iconSize: CGFloat = 22

    private var totalWidth: CGFloat {
        slotWidth * CGFloat(AppTab.allCases.count)
    }

    private var clampedProgress: Double {
        min(max(0, progress), Double(AppTab.allCases.count - 1))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Single persistent Liquid Glass pill that tracks progress.
            // Slight width stretch while dragging gives the morph.
            let pillWidth = slotWidth - pillInset * 2
            let stretch: CGFloat = isDragging ? 10 : 0
            Capsule(style: .continuous)
                .fill(Color.clear)
                .frame(width: pillWidth + stretch, height: pillHeight - pillInset * 2)
                .tayaGlass(
                    in: Capsule(style: .continuous),
                    tint: Theme.glassChromeTint,
                    interactive: true
                )
                .offset(
                    x: CGFloat(clampedProgress) * slotWidth + pillInset - stretch / 2,
                    y: 0
                )
                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isDragging)

            // Icons sit on top so they read clearly against the pill.
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    icon(for: tab)
                        .frame(width: slotWidth, height: pillHeight)
                }
            }
        }
        .frame(width: totalWidth, height: pillHeight)
        .contentShape(Rectangle())
        .gesture(barGesture)
    }

    @ViewBuilder
    private func icon(for tab: AppTab) -> some View {
        let s = selectedness(for: tab)
        Image(systemName: s > 0.5 ? tab.iconSystemNameFilled : tab.iconSystemName)
            .font(.system(size: iconSize, weight: s > 0.5 ? .semibold : .regular))
            .foregroundStyle(Theme.accent.opacity(0.7 + 0.3 * s))
            .symbolRenderingMode(.monochrome)
            .accessibilityLabel(tab.accessibilityLabel)
            .accessibilityAddTraits(s > 0.5 ? .isSelected : [])
    }

    /// Single bar-wide gesture handles both tap and drag. Tapping a slot
    /// snaps the pill there; dragging scrubs progress continuously and
    /// snaps to the nearest slot on release.
    private var barGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging && abs(value.translation.width) > 2 {
                    isDragging = true
                }
                let x = max(0, min(totalWidth, value.location.x))
                let raw = (x / slotWidth) - 0.5
                let clamped = min(max(0, raw), CGFloat(AppTab.allCases.count - 1))
                progress = Double(clamped)
            }
            .onEnded { value in
                let snapped = clampedProgress.rounded()
                withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                    progress = snapped
                    isDragging = false
                }
                if let tab = AppTab.at(Int(snapped)) {
                    onSelect(tab)
                }
            }
    }

    private func selectedness(for tab: AppTab) -> Double {
        max(0, 1 - abs(Double(tab.index) - clampedProgress))
    }
}

#Preview {
    struct Wrapper: View {
        @State var progress: Double = 0
        var body: some View {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        TayaBottomNav(progress: $progress, onSelect: { _ in })
                        Spacer()
                        PlusButton(onCapture: {}, onAddNote: {}, onAddTask: {})
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
    }
    return Wrapper()
}
