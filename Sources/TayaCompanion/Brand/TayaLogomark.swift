import SwiftUI

/// The Taya logomark — the ring/lens silhouette that pairs with the
/// wordmark. Rendered as a template image so callers tint it with
/// `.foregroundStyle`.
struct TayaLogomark: View {
    var size: CGFloat

    init(size: CGFloat = 28) {
        self.size = size
    }

    var body: some View {
        Image("TayaLogomark", bundle: .module)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Taya")
    }
}
