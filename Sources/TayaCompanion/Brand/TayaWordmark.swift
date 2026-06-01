import SwiftUI

/// The TAYA wordmark, rendered as a template image so callers tint it with
/// `.foregroundStyle`.
struct TayaWordmark: View {
    var width: CGFloat

    init(width: CGFloat = 120) {
        self.width = width
    }

    var body: some View {
        Image("TayaWordmark", bundle: .module)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityLabel("Taya")
    }
}
