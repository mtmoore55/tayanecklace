import SwiftUI

enum TayaColors {
    static let skyBlue     = blue300
    static let oxfordBlue  = Color(red:  13/255, green:  41/255, blue:  81/255)
    static let cornsilk    = Color(red: 255/255, green: 246/255, blue: 220/255)
    static let cosmicLatte = Color(red: 255/255, green: 249/255, blue: 230/255)

    static let blue300 = Color(red: 156/255, green: 182/255, blue: 209/255)
    static let blue400 = Color(red: 117/255, green: 149/255, blue: 181/255)
    static let blue500 = Color(red:  72/255, green: 115/255, blue: 160/255)

    /// The one warning/error accent. Warm amber tuned to read on both the
    /// light and dark gradient bands without flipping into pure red — sits
    /// adjacent to the blue family rather than fighting it. Used by the
    /// StatusBanner, the necklace pill's warning glyph, and the device
    /// sheet's error rows.
    static let warningAmber = Color(red: 244/255, green: 179/255, blue: 87/255)
}
