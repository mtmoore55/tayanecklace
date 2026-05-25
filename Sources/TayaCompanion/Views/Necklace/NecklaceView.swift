import SwiftUI
import TayaIntelligence

struct NecklaceView: View {
    @Environment(\.gesturePhase) private var gesturePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Necklace")
                    .font(Theme.screenTitle())
                    .padding(.top, 12)

                Card {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(TayaColors.skyBlue)
                            Circle()
                                .trim(from: 0, to: 0.72)
                                .stroke(TayaColors.oxfordBlue.opacity(0.5),
                                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 36, height: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Battery").font(Theme.caption())
                                .foregroundStyle(Theme.secondaryText)
                            Text("72%").font(Theme.cardTitle())
                        }
                        Spacer()
                    }
                }

                Card {
                    Text("Necklace placeholder — pairing state, signal, firmware, and capture history land here in Phase 3.")
                        .font(Theme.body())
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDisabled(gesturePhase == .horizontalSwipe)
    }
}

#Preview {
    NecklaceView()
        .environment(DataStore.seeded(now: Date()))
}
