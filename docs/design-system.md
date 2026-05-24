# Taya Design System

The source-of-truth reference for visual primitives shared between Figma and the `TayaIntelligence` Swift package. Figma is the source of truth for *applied* design (screens, components, flows); this document is the source of truth for the *primitives and semantics* underneath.

When Figma and this document disagree, this document wins — and Figma should be updated to match.

---

## Typography

### Principles

1. **Two font families, one crossover.** Aguila is used for display type only (≥24pt). SF Pro is used for everything ≤22pt. Nothing in between. This rule is non-negotiable — without it the system drifts.
2. **One weight per display size.** Aguila weight is pinned to size, not chosen freely (Light at the top where high contrast is most beautiful, Medium at the bottom where strokes need presence).
3. **Body type is iOS-native.** SF Pro sizes map 1:1 to iOS Dynamic Type categories so Taya's engineers get accessibility scaling for free. Aguila requires a custom `UIFontMetrics` scaler to participate in Dynamic Type.
4. **Semantic tokens reference primitives.** Components reference semantic tokens (`Heading/Page`), never primitives (`Display/L`). The primitive layer can be re-tuned without touching components.
5. **No emphasis tokens.** Emphasis is a weight override on a span; links are a color + underline treatment. We do not maintain `Body/Emphasized` or `Link` tokens.

### Primitives — Display tier (Aguila)

Aguila ≥24pt only. Tracking is percentage of em.

| Token | Weight | Size | Line height | Tracking |
|---|---|---|---|---|
| `Display/XL` | Light | 56 | 60 | -1% |
| `Display/L` | Light | 40 | 46 | -0.5% |
| `Display/M` | Regular | 32 | 38 | -0.25% |
| `Display/S` | Medium | 24 | 30 | 0 |

### Primitives — Text tier (SF Pro)

SF Pro ≤22pt only. Tracking is absolute (pt), matching Apple's iOS defaults so Figma and rendered output agree.

| Token | Weight | Size | Line height | Tracking | iOS Dynamic Type |
|---|---|---|---|---|---|
| `Text/Title L` | Semibold | 22 | 28 | +0.35 | `.title2` |
| `Text/Title M` | Semibold | 20 | 25 | +0.38 | `.title3` |
| `Text/Title S` | Semibold | 17 | 22 | -0.41 | `.headline` |
| `Text/Body L` | Regular | 17 | 24 | -0.41 | `.body` |
| `Text/Body M` | Regular | 15 | 20 | -0.24 | `.subheadline` |
| `Text/Body S` | Regular | 13 | 18 | -0.08 | `.footnote` |
| `Text/Caption` | Regular | 12 | 16 | 0 | `.caption1` |
| `Text/Micro` | Medium | 11 | 13 | +0.07 | `.caption2` |

### Semantic tokens

The semantic layer is what components reference. Each maps to exactly one primitive.

| Semantic token | → Primitive | Use |
|---|---|---|
| `Heading/Hero` | `Display/XL` | Onboarding, brand moments — at most once per flow |
| `Heading/Page` | `Display/L` | Screen titles, large empty states |
| `Heading/Section` | `Display/M` | Major groupings within a screen |
| `Heading/Subsection` | `Display/S` | Editorial card headers, modal titles |
| `Heading/Card` | `Text/Title L` | Card and list-group titles |
| `Heading/Item` | `Text/Title M` | List-item titles, inline section headers |
| `Eyebrow` | `Text/Micro` Medium, **uppercase**, +6% tracking | Small kicker above a heading |
| `Body/Default` | `Text/Body L` | Default paragraph copy |
| `Body/Compact` | `Text/Body M` | Dense areas, secondary copy |
| `Body/Tight` | `Text/Body S` | Metadata strips, dense lists |
| `Label/Default` | `Text/Title S` | Form labels, primary button, list-row titles |
| `Label/Compact` | `Text/Body M` Medium | Secondary buttons, chips, tab labels |
| `Caption` | `Text/Caption` | Image captions, timestamps, footnotes |
| `Helper` | `Text/Body S` | Form helper, error, and hint text |

### Color pairing rules

Display type is set in **Oxford Blue** (`#0D2951`) or **Black** on light backgrounds. Avoid **Sky Blue** (`#9CB6D1`) at display sizes — contrast disappears against Cornsilk / Cosmic Latte. See the color section (TBD) for full rules.

---

## Implementation notes

### Figma

- Primitives and semantics both live as text styles in the published `Taya / Foundations` library.
- Font family, weight, and size are bound to variables in the `Typography` collection so primitives can be re-tuned in one place.
- A `Typography` canvas page in the foundations file shows every semantic style with its resolved primitive labeled — that page is the visual spec.

### Swift (`TayaIntelligence`)

When typography is wired into the library, it will live at `Sources/TayaIntelligence/TayaTypography.swift` and expose:

- `Font.tayaHeadingHero`, `Font.tayaHeadingPage`, … — one accessor per semantic token, kebab-case → camelCase.
- Aguila registration: `.otf` files bundled in `Sources/TayaIntelligence/Resources/Fonts/`, registered at module load via `CTFontManagerRegisterFontsForURLs`.
- Dynamic Type for Aguila: wrap the custom font in `UIFontMetrics(forTextStyle:).scaledFont(for:)` so it respects the user's text-size setting. SF Pro tokens pass through to `Font.title2`, `Font.body`, etc., and scale automatically.
- The semantic API is what components consume. Primitives are not exposed publicly.

### Token export pipeline

The Figma `Typography` variable collection is exported to JSON via the **Tokens Studio for Figma** plugin. The exported JSON is committed to the repo at `docs/tokens/typography.json` and is the input that generates `TayaTypography.swift`. This keeps Figma and Swift from drifting — values are transcribed exactly once, by a script, not by hand.
