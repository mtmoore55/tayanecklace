import SwiftUI
import TayaIntelligence

/// App-wide visual tokens. Brand palette lives in `TayaIntelligence.TayaColors`
/// (the orb library); this Theme layer is the app-facing surface — backgrounds,
/// cards, accent, type scale. Keep all hex/RGB definitions here so we tune in
/// one place.
public enum Theme {
    // Background — warm, slightly cool off-white. Sits behind cards.
    public static let background = Color(red: 0.945, green: 0.949, blue: 0.957)

    // Cards
    public static let cardSurface = Color.white
    public static let cardShadow = Color.black.opacity(0.06)
    public static let cardCorner: CGFloat = 16

    // Accent — text and icon accents (selected tab text, chip text,
    // sparkle icons, etc). Brand oxford blue gives high contrast on
    // white surfaces while staying in palette.
    public static let accent = TayaColors.oxfordBlue

    // Soft accent fills (chip background, etc.).
    // A pale sky blue tint reads as part of the brand family.
    public static let accentSoft = TayaColors.skyBlue.opacity(0.22)

    // Pale brand blue used for inactive nav circles. Roughly the "blue-50"
    // tint from the mockup.
    public static let blue50 = TayaColors.skyBlue.opacity(0.28)

    // Capture button — on-brand sky blue (#9CB6D1).
    public static let captureFill = TayaColors.skyBlue
    public static let captureShadow = TayaColors.skyBlue.opacity(0.45)

    // Text
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary

    // Type — small helpers keep weights consistent across screens
    public static func screenTitle() -> Font { .system(.largeTitle, design: .default, weight: .semibold) }
    public static func sectionTitle() -> Font { .system(.title2, design: .default, weight: .semibold) }
    public static func cardTitle() -> Font { .system(.headline, design: .default, weight: .semibold) }
    public static func body() -> Font { .system(.body, design: .default, weight: .regular) }
    public static func caption() -> Font { .system(.footnote, design: .default, weight: .regular) }
    public static func eyebrow() -> Font { .system(size: 11, weight: .semibold, design: .default) }
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
