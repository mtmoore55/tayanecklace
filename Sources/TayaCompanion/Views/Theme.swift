import SwiftUI

/// App-wide visual tokens. Single colorway in each mode, anchored on a
/// muted mid sky-blue (light) / deep navy (dark) gradient. Every
/// surface uses the same glass recipe; every body text is white;
/// only icon/accent color flips between modes.
public enum Theme {
    // MARK: - Background

    /// Canonical page background. Two-stop vertical gradient anchored on
    /// brand blues — `blue500` (#4873A0) at the top, `skyBlue` (#9CB6D1)
    /// at the bottom. Documented in `docs/design-system.md` under Color.
    /// In dark mode the same shape inverts to a deep navy → mid-blue band
    /// so night scenes still read as night.
    public static let backgroundGradient = LinearGradient(
        stops: [
            .init(
                color: .dynamic(
                    light: TayaColors.blue500,
                    dark:  Color(red: 0.012, green: 0.035, blue: 0.105)
                ),
                location: 0.0
            ),
            .init(
                color: .dynamic(
                    light: TayaColors.skyBlue,
                    dark:  Color(red: 0.50, green: 0.62, blue: 0.78)
                ),
                location: 1.0
            ),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Solid fallback. Matches the gradient's mid band in each mode.
    public static let background = Color.dynamic(
        light: Color(red: 0.42, green: 0.53, blue: 0.66),
        dark:  Color(red: 0.05, green: 0.12, blue: 0.24)
    )

    // MARK: - Glass surfaces

    /// One glass recipe used by every surface (cards, pills, the
    /// selected nav capsule). Consistent fill + stroke values are the
    /// whole point of pulling these out as named tokens.
    public static let glassFill   = Color.white.opacity(0.06)
    public static let glassStroke = Color.white.opacity(0.05)

    /// Darkening tint on the card glass. Native `.regular` glass frosts
    /// much lighter than our saturated gradient, which washes out the
    /// white body text; a deep-navy tint pulls the surface back below the
    /// gradient's luminance so white text reads, while it still responds
    /// to motion as honest Liquid Glass. This is the contrast dial.
    public static let glassCardTint: Color = TayaColors.oxfordBlue.opacity(0.38)

    /// Blue tint applied to the chrome's Liquid Glass surfaces (the
    /// selected tab pill and the Plus button) so they lift cleanly off
    /// the gradient in both modes while staying in the brand blue family.
    /// A white tint here reads as flat gray against the navy; sky-blue
    /// keeps the chrome feeling like tinted glass rather than plastic.
    public static let glassChromeTint: Color = TayaColors.skyBlue.opacity(0.32)

    /// Slightly more opaque variant for surfaces that need dark icons
    /// or text on top (the top-right NecklaceProfilePill, the Plus
    /// button) — the extra opacity gives the dark glyph a brighter
    /// backdrop to read against.
    public static let glassFillStrong   = Color.white.opacity(0.28)
    public static let glassStrokeStrong = Color.white.opacity(0.45)

    // Legacy aliases so existing call sites keep working while the
    // system tightens. Prefer the `glass*` tokens above for new work.
    public static var cardSurface: Color { glassFill }
    public static var cardStroke: Color  { glassStroke }
    public static let cardShadow = Color.black.opacity(0.18)
    public static let cardCorner: CGFloat = 18

    // MARK: - Card glass recipe
    //
    // The full set of values behind `tayaGlassCard` — the single surface
    // recipe shared by cards and any glass status surface (e.g. the
    // necklace "Connected" pill). Native `.regular` Liquid Glass tinted
    // with `glassCardTint` for legibility, edged with a hairline
    // `glassStroke`, and lifted off the page by a soft shadow.
    public static let cardStrokeWidth: CGFloat  = 0.75
    public static let cardShadowRadius: CGFloat = 14
    public static let cardShadowYOffset: CGFloat = 6

    // MARK: - Text

    /// Body text — always white. The gradient is dark enough in both
    /// modes that white is the only color that reads cleanly on the
    /// background AND on the glass cards (which sit slightly lighter
    /// than the bg but still in the same dark-blue family).
    public static let primaryText   = Color.white
    public static let secondaryText = Color.white.opacity(0.75)
    public static let tertiaryText  = Color.white.opacity(0.55)

    // Legacy aliases. The previous "on gradient" tokens collapsed into
    // primaryText now that everything is white. Kept as references.
    public static var onGradientPrimary: Color   { primaryText }
    public static var onGradientSecondary: Color { secondaryText }
    public static var onGradientTertiary: Color  { tertiaryText }

    // MARK: - Icon / accent

    /// Dark navy when the icon sits on a light glass capsule (light
    /// mode), white when it sits on a dark glass capsule (dark mode).
    /// Use for nav icons, the top-right pill text, and the Plus glyph.
    public static let accent = Color.dynamic(
        light: TayaColors.oxfordBlue,
        dark:  Color.white
    )

    /// Tertiary tint for *decorative* icons on Home only — empty task
    /// checkboxes, place/theme chip glyphs. A pale blue that recedes
    /// beneath the white primary text (more depth than pure white) and
    /// sits in the same quiet register as the eyebrow labels. Do NOT use
    /// for the battery pill or tab bar — those stay on `accent`.
    public static let homeIcon = Color(red: 0.78, green: 0.85, blue: 0.93)
    /// Inverse of `accent`. Use for text or glyphs that sit on top of an
    /// `accent`-filled surface (the Ask Taya pill, chat send button) so
    /// the foreground reads in both modes — white on dark navy in light
    /// mode, dark navy on white in dark mode.
    public static let onAccent = Color.dynamic(
        light: Color.white,
        dark:  TayaColors.oxfordBlue
    )
    public static let accentSoft = Color.white.opacity(0.15)
    public static let blue50     = TayaColors.skyBlue.opacity(0.20)

    public static let captureFill   = TayaColors.skyBlue
    public static let captureShadow = TayaColors.skyBlue.opacity(0.45)

    // MARK: - Chrome

    public static let topFadeHeight: CGFloat = 24
    public static let bottomFadeHeight: CGFloat = 48
    public static let pageContentTopInset: CGFloat = 12
    public static let pageContentBottomInset: CGFloat = 140
    /// Width of the bottom nav row (three 76pt tab slots + 12pt spacing +
    /// 64pt Plus button). The Chat composer aligns to this same width so
    /// it visually sits inside the same chrome column.
    public static let bottomChromeRowWidth: CGFloat = 76 * 3 + 12 + 64

    /// Bottom padding for the Chat tab's composer pill. Tuned so the
    /// composer sits just above the bottom nav row (which lives in
    /// `RootView.bottomChrome` and floats over the page content).
    public static let chatComposerBottomInset: CGFloat = 96

    // MARK: - Type

    public static func displayXL() -> Font { .custom("Aguila-Medium", size: 28) }
    public static func displayHero() -> Font { .custom("CentraleSansMedium", size: 56) }
    public static func displayLarge() -> Font { .custom("CentraleSansMedium", size: 40) }
    public static func displayMedium() -> Font { .custom("CentraleSansBold", size: 22) }
    public static func displaySmall() -> Font { .custom("CentraleSansBold", size: 24) }

    /// Brand-serif greeting. 38pt; pair with `.lineSpacing(-10)` at
    /// the call site to render 100% line-height (so stacked words
    /// like "Good / afternoon" sit tight).
    public static func greeting() -> Font { .custom("Aguila-Medium", size: 38) }
    public static func summary() -> Font  { .system(size: 22, weight: .regular) }

    // SF Pro for the entire text tier per docs/design-system.md
    // (Text/Title L/M/S are all Semibold SF Pro). Previously these two
    // were CentraleSansBold — a deviation from the documented system.
    public static func titleL() -> Font { .system(size: 22, weight: .semibold) }
    public static func titleM() -> Font { .system(size: 20, weight: .semibold) }
    public static func titleS() -> Font { .system(size: 17, weight: .semibold) }

    public static func bodyL() -> Font { .system(size: 17, weight: .regular) }
    public static func bodyM() -> Font { .system(size: 16, weight: .regular) }
    public static func bodyS() -> Font { .system(size: 13, weight: .regular) }

    public static func caption() -> Font { .system(size: 13, weight: .regular) }
    public static func micro() -> Font { .custom("CentraleSansMedium", size: 11) }

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

public extension View {
    /// Real Apple Liquid Glass material on iOS 26+ (responds to motion
    /// and ambient light), with a static fill+stroke fallback on older
    /// systems so the rest of the design still reads as glass. Pass any
    /// `Shape` — Circle for avatars, Capsule for chips, RoundedRectangle
    /// for cards.
    /// Real Apple Liquid Glass on iOS 26+ — responds to motion and
    /// ambient light. Use for surfaces that *should* read as a tactile
    /// glass control: the selected tab pill, the Plus button. Cards use
    /// `tayaGlassCard`, which wraps the same material with a card-tuned
    /// tint and a lift shadow.
    @ViewBuilder
    func tayaGlass<S: Shape>(
        in shape: S,
        tint: Color = .clear,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(
                .regular.tint(tint).interactive(interactive),
                in: shape
            )
        } else {
            self
                .background(shape.fill(tint))
                .background(shape.fill(Theme.glassFill))
                .overlay(shape.stroke(Theme.glassStroke, lineWidth: 1))
                .shadow(color: Theme.cardShadow, radius: 10, x: 0, y: 4)
        }
    }

    /// Native Liquid Glass card surface. Uses the real `glassEffect`
    /// material so cards respond to motion and ambient light (the same
    /// dynamism as the chrome), lifted off the page with a soft shadow.
    /// A subtle dark tint (`glassCardTint`) keeps the white body text
    /// readable against the lighter frost, and a hairline stroke crisps
    /// the edge.
    @ViewBuilder
    func tayaGlassCard<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self
                .glassEffect(.regular.tint(Theme.glassCardTint), in: shape)
                .overlay(shape.stroke(Theme.glassStroke, lineWidth: Theme.cardStrokeWidth))
                .shadow(color: Theme.cardShadow, radius: Theme.cardShadowRadius, x: 0, y: Theme.cardShadowYOffset)
        } else {
            self
                .background(shape.fill(Color.white.opacity(0.12)))
                .overlay(shape.stroke(Color.white.opacity(0.28), lineWidth: Theme.cardStrokeWidth))
                .shadow(color: Theme.cardShadow, radius: Theme.cardShadowRadius, x: 0, y: Theme.cardShadowYOffset)
        }
    }
}

/// Canonical glass surface. Used by every Card site in the app —
/// single source of truth so the system stays consistent.
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
            .tayaGlassCard(
                in: RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
            )
    }
}
