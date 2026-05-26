import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    /// Returns a Color that resolves to `light` in Light mode and `dark`
    /// in Dark mode (iOS only; on other platforms returns `light`).
    static func dynamic(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { trait in
            UIColor(trait.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        return light
        #endif
    }
}
