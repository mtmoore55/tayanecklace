import SwiftUI

public struct SplashView: View {
    public var onFinish: (() -> Void)?

    @State private var phase: Phase = .initial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase {
        case initial
        case visible
        case gone
    }

    public init(onFinish: (() -> Void)? = nil) {
        self.onFinish = onFinish
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [TayaColors.blue300, TayaColors.blue400],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("TayaWordmark", bundle: .module)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 182)

                Image("JewelryThatRemembers", bundle: .module)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 305)
            }
            .foregroundStyle(.white)
            .opacity(contentOpacity)
            .offset(y: contentOffset)
        }
        .task {
            await play()
        }
    }

    private var contentOpacity: Double {
        switch phase {
        case .initial, .gone: return 0
        case .visible:        return 1
        }
    }

    private var contentOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        switch phase {
        case .initial: return  20
        case .visible: return   0
        case .gone:    return -20
        }
    }

    private func play() async {
        withAnimation(.easeOut(duration: 0.8)) {
            phase = .visible
        }
        try? await Task.sleep(for: .milliseconds(2_200))
        withAnimation(.easeIn(duration: 0.7)) {
            phase = .gone
        }
        try? await Task.sleep(for: .milliseconds(700))
        onFinish?()
    }
}
