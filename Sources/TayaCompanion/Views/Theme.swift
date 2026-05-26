import SwiftUI
import TayaIntelligence

/// App-wide visual tokens. Brand palette lives in `TayaIntelligence.TayaColors`
/// (the orb library); this Theme layer is the app-facing surface — backgrounds,
/// cards, accent, type scale. Keep all hex/RGB definitions here so we tune in
/// one place.
public enum Theme {
    // Background — warm, slightly cool off-white in light; deep blue-grey in dark.
    public static let background = Color.dynamic(
        light: Color(red: 0.945, green: 0.949, blue: 0.957),
        dark:  Color(red: 0.055, green: 0.075, blue: 0.110)
    )

    // Cards — pure white in light; slightly lighter dark surface above background.
    public static let cardSurface = Color.dynamic(
        light: .white,
        dark:  Color(red: 0.105, green: 0.130, blue: 0.165)
    )
    public static let cardShadow = Color.dynamic(
        light: Color.black.opacity(0.06),
        dark:  Color.black.opacity(0.40)
    )
    public static let cardCorner: CGFloat = 16

    // Accent — used by selected-tab text, chip text, sparkle icons.
    // Switches from oxfordBlue (light) to skyBlue (dark) for readability.
    public static let accent = Color.dynamic(
        light: TayaColors.oxfordBlue,
        dark:  TayaColors.skyBlue
    )

    // Soft accent fills (chip background, etc.).
    public static let accentSoft = Color.dynamic(
        light: TayaColors.skyBlue.opacity(0.22),
        dark:  TayaColors.skyBlue.opacity(0.18)
    )

    // Pale brand blue used for inactive nav circles.
    public static let blue50 = Color.dynamic(
        light: TayaColors.skyBlue.opacity(0.28),
        dark:  TayaColors.skyBlue.opacity(0.16)
    )

    // Capture button — on-brand sky blue (#9CB6D1).
    public static let captureFill = TayaColors.skyBlue
    public static let captureShadow = TayaColors.skyBlue.opacity(0.45)

    // Text
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary

    // Chrome — heights of the gradient fades above/below page content.
    public static let topFadeHeight: CGFloat = 28
    public static let bottomFadeHeight: CGFloat = 56

    // Page content should clear enough room above/below for the chrome
    // (top nav + top fade, composer + bottom fade) plus a small comfort
    // margin so the first/last visible item isn't right at the seam.
    public static let pageContentTopInset: CGFloat = 36
    public static let pageContentBottomInset: CGFloat = 160

    // Type — mirrors the Figma type scale 1:1. CentraleSans for display
    // and brand titles; SF Pro (system) for body and small UI text.
    // Sizes/tracking are pulled straight from the Figma Typography frame.

    // Display
    public static func displayXL() -> Font { .custom("Aguila-Medium", size: 28) }                  // primary, special use
    public static func displayHero() -> Font { .custom("CentraleSansMedium", size: 56) }          // alt XL
    public static func displayLarge() -> Font { .custom("CentraleSansMedium", size: 40) }
    public static func displayMedium() -> Font { .custom("CentraleSansBold", size: 22) }
    public static func displaySmall() -> Font { .custom("CentraleSansBold", size: 24) }

    // Titles
    public static func titleL() -> Font { .custom("CentraleSansBold", size: 22) }
    public static func titleM() -> Font { .custom("CentraleSansBold", size: 20) }
    public static func titleS() -> Font { .system(size: 17, weight: .semibold) }

    // Body
    public static func bodyL() -> Font { .system(size: 17, weight: .regular) }
    public static func bodyM() -> Font { .system(size: 15, weight: .regular) }
    public static func bodyS() -> Font { .system(size: 13, weight: .regular) }

    // Small
    public static func caption() -> Font { .system(size: 12, weight: .regular) }
    public static func micro() -> Font { .custom("CentraleSansMedium", size: 11) }

    // Tracking values from Figma (in points). Apply at the call site
    // alongside the font: `Text(...).font(Theme.titleL()).tracking(Theme.titleLTracking)`.
    public static let displayXLTracking: CGFloat = -0.28
    public static let displayHeroTracking: CGFloat = -0.56
    public static let displayLargeTracking: CGFloat = -0.40
    public static let displayMediumTracking: CGFloat = -0.08
    public static let titleLTracking: CGFloat = 0.077
    public static let titleMTracking: CGFloat = 0.076
    public static let titleSTracking: CGFloat = -0.07
    public static let bodyLTracking: CGFloat = -0.07
    public static let bodyMTracking: CGFloat = -0.036
    public static let bodySTracking: CGFloat = -0.01
    public static let microTracking: CGFloat = 0.008
}

/// Standard card chrome — white surface, rounded, soft shadow.
public struct Card<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    public init(padding: CGFloat = 16, @ViewBuilder _ content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous))
            .shadow(color: Theme.cardShadow, radius: 8, x: 0, y: 2)
    }
}
