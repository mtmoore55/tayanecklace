import SwiftUI

/// The TAYA wordmark, rendered as a template image so callers tint it with
/// `.foregroundStyle`. Lives here (not in `TayaCompanion`) because the
/// asset ships in this module's resource bundle; exposing it as a view lets
/// any module use it without reaching for `Bundle.module` directly.
public struct TayaWordmark: View {
    public var width: CGFloat

    public init(width: CGFloat = 120) {
        self.width = width
    }

    public var body: some View {
        Image("TayaWordmark", bundle: .module)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityLabel("Taya")
    }
}
