import SwiftUI

/// The Taya logomark — the ring/lens silhouette that pairs with the
/// wordmark. Rendered as a template image so callers tint it with
/// `.foregroundStyle`. Mirrors `TayaWordmark`'s approach so any module
/// can use it without reaching for `Bundle.module` directly.
public struct TayaLogomark: View {
    public var size: CGFloat

    public init(size: CGFloat = 28) {
        self.size = size
    }

    public var body: some View {
        Image("TayaLogomark", bundle: .module)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Taya")
    }
}
