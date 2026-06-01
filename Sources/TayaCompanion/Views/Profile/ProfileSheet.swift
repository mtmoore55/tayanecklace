import SwiftUI

/// How the app picks its colorway. `auto` follows time-of-day (the design
/// default); `day`/`night` force one appearance — handy for review and as
/// a real user preference.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case auto, day, night

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto:  return "Auto"
        case .day:   return "Day"
        case .night: return "Night"
        }
    }

    /// Resolves to the concrete scheme the app should render. `auto` defers
    /// to the supplied time-of-day flag.
    func colorScheme(isNight: Bool) -> ColorScheme {
        switch self {
        case .auto:  return isNight ? .dark : .light
        case .day:   return .light
        case .night: return .dark
        }
    }
}

/// Which lens the Mirror (Home's hero block) presents. `reflection` is the
/// default; the others swap in different facets of the day. Surfaced in the
/// Profile sheet as a preview control for now — longer-term Taya picks this
/// automatically rather than the user choosing a mode.
enum MirrorLens: String, CaseIterable, Identifiable {
    case reflection, forYou, focus, revisit, people, themes

    var id: String { rawValue }

    var label: String {
        switch self {
        case .reflection: return "Reflection"
        case .forYou:     return "For you"
        case .focus:      return "Focus"
        case .revisit:    return "Revisit"
        case .people:     return "People"
        case .themes:     return "Themes"
        }
    }
}

/// Lightweight profile sheet opened from the avatar in the top-right pill.
/// Holds the user identity and an appearance control.
struct ProfileSheet: View {
    let userInitial: String
    @Binding var appearance: AppearanceMode
    @Binding var mirrorLens: MirrorLens

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    appearanceSection
                    mirrorLensSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Profile")
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.backgroundGradient)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text(userInitial)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(TayaColors.oxfordBlue)
                .frame(width: 88, height: 88)
                .background(Circle().fill(Color.white.opacity(0.92)))
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)

            HStack(spacing: 8) {
                ForEach(AppearanceMode.allCases) { mode in
                    pill(for: mode)
                }
            }
        }
    }

    private func pill(for mode: AppearanceMode) -> some View {
        let selected = appearance == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { appearance = mode }
        } label: {
            Text(mode.label)
                .font(Theme.bodyM())
                .foregroundStyle(selected ? Theme.onAccent : Theme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? Theme.accent : Color.white.opacity(0.12))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(selected ? 0 : 0.28), lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var mirrorLensSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mirror")
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            Text("Preview how the Mirror reflects your day.")
                .font(Theme.caption())
                .foregroundStyle(Theme.tertiaryText)

            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(MirrorLens.allCases) { lens in
                    lensPill(for: lens)
                }
            }
            .padding(.top, 2)
        }
    }

    private func lensPill(for lens: MirrorLens) -> some View {
        let selected = mirrorLens == lens
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { mirrorLens = lens }
        } label: {
            Text(lens.label)
                .font(Theme.bodyM())
                .foregroundStyle(selected ? Theme.onAccent : Theme.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? Theme.accent : Color.white.opacity(0.12))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(selected ? 0 : 0.28), lineWidth: 0.75)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ProfileSheet(userInitial: "E", appearance: .constant(.auto), mirrorLens: .constant(.reflection))
        }
}
