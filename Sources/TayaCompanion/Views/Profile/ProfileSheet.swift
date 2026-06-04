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
    /// Display name + contact email shown in the realistic identity header.
    /// Demo-grade today; engineering wires these to the account model.
    let userName: String
    let userEmail: String
    @Binding var appearance: AppearanceMode
    @Binding var mirrorLens: MirrorLens
    /// Demo-grade toggle. Taya's engineers replace this surface with real
    /// reachability (NWPathMonitor + BLE) — the rest of the app keeps
    /// reading from `AmbientState.connectivity` unchanged.
    @Binding var connectivity: ConnectivityStatus
    /// Demo-grade battery percent for the necklace. Engineers replace this
    /// with BLE-reported state; views keep reading `AmbientState.necklaceBattery`.
    @Binding var batteryPercent: Int
    /// Demo-grade charging toggle. Engineers replace with the real
    /// cradle-detected signal.
    @Binding var isCharging: Bool
    /// Per-category push opt-ins. Engineers wire each flag into APNs
    /// registration / server-side gating; the UI here is the user seam.
    @Binding var notifications: NotificationPreferences

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    appearanceSection
                    notificationsLink
                    mirrorLensSection
                    connectivitySection
                    batterySection
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
        VStack(spacing: 10) {
            Text(userInitial)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(TayaColors.oxfordBlue)
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color.white.opacity(0.92)))
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))

            VStack(spacing: 2) {
                Text(userName)
                    .font(Theme.bodyL().weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text(userEmail)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.tertiaryText)
            }
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
            Text("Mirror (demo)")
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

    // MARK: - Notifications (disclosure into submenu)

    /// One-row entry that pushes `NotificationsSubmenu` onto the sheet's
    /// nav stack. The toggles themselves live one level deeper so the
    /// top-level Profile stays scannable.
    private var notificationsLink: some View {
        NavigationLink {
            NotificationsSubmenu(notifications: $notifications)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 20)
                Text("Notifications")
                    .font(Theme.bodyM())
                    .foregroundStyle(Theme.primaryText)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Connectivity (demo)

    private var connectivitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connectivity (demo)")
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            Text("Flip the app between online and degraded states to preview the status banner and the offline capture flow.")
                .font(Theme.caption())
                .foregroundStyle(Theme.tertiaryText)

            VStack(spacing: 8) {
                ForEach(ConnectivityStatus.allCases) { status in
                    connectivityPill(for: status)
                }
            }
            .padding(.top, 2)
        }
    }

    private func connectivityPill(for status: ConnectivityStatus) -> some View {
        let selected = connectivity == status
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { connectivity = status }
            Haptics.selection()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: connectivityIcon(for: status))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? Theme.onAccent : connectivityIconTint(for: status))
                    .frame(width: 20)
                Text(connectivityLabel(for: status))
                    .font(Theme.bodyM())
                    .foregroundStyle(selected ? Theme.onAccent : Theme.primaryText)
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                }
            }
            .padding(.horizontal, 14)
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

    private func connectivityLabel(for status: ConnectivityStatus) -> String {
        switch status {
        case .ok:                  return "Online"
        case .necklaceUnreachable: return "Necklace not connected"
        case .networkUnreachable:  return "No internet"
        case .syncFailed:          return "Sync error"
        }
    }

    private func connectivityIcon(for status: ConnectivityStatus) -> String {
        switch status {
        case .ok:                  return "checkmark.circle"
        case .necklaceUnreachable: return "bolt.horizontal.circle"
        case .networkUnreachable:  return "wifi.slash"
        case .syncFailed:          return "exclamationmark.arrow.triangle.2.circlepath"
        }
    }

    private func connectivityIconTint(for status: ConnectivityStatus) -> Color {
        status == .ok ? Theme.secondaryText : TayaColors.warningAmber
    }

    // MARK: - Battery (demo)

    /// Preset levels surfaced in the battery simulator. The percent each
    /// writes sits squarely inside the matching `BatteryDisplayState`
    /// bucket so the pill selection and the rest of the chrome agree.
    private enum BatteryPreset: String, CaseIterable, Identifiable {
        case full, healthy, low, critical

        var id: String { rawValue }
        var label: String {
            switch self {
            case .full:     return "Full"
            case .healthy:  return "Healthy"
            case .low:      return "Low"
            case .critical: return "Critical"
            }
        }
        var percent: Int {
            switch self {
            case .full:     return 100
            case .healthy:  return 60
            case .low:      return 15
            case .critical: return 4
            }
        }
        var sublabel: String { "\(percent)%" }

        /// Which preset a given percent rolls up to. Mirrors the
        /// `BatteryDisplayState` thresholds in AmbientState.
        static func bucket(for percent: Int) -> BatteryPreset {
            switch percent {
            case ..<8:   return .critical
            case 8..<20: return .low
            case 95...:  return .full
            default:     return .healthy
            }
        }
    }

    private var batterySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Battery (demo)")
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            Text("Flip charging and pick a battery preset to preview pill tints, the critical-battery banner, and device-sheet copy.")
                .font(Theme.caption())
                .foregroundStyle(Theme.tertiaryText)

            chargingPill
                .padding(.top, 2)

            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(BatteryPreset.allCases) { preset in
                    batteryPresetPill(for: preset)
                }
            }
        }
    }

    private var chargingPill: some View {
        let selected = isCharging
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { isCharging.toggle() }
            Haptics.selection()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(selected ? Theme.onAccent : Theme.accent)
                    .frame(width: 20)
                Text("Charging")
                    .font(Theme.bodyM())
                    .foregroundStyle(selected ? Theme.onAccent : Theme.primaryText)
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.onAccent)
                }
            }
            .padding(.horizontal, 14)
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

    private func batteryPresetPill(for preset: BatteryPreset) -> some View {
        // Selected when the current percent sits in this preset's bucket,
        // but only when not charging — charging mutes the level highlight
        // so the row reads as "charging takes precedence."
        let selected = !isCharging && BatteryPreset.bucket(for: batteryPercent) == preset
        let tint: Color = (preset == .low || preset == .critical) ? TayaColors.warningAmber : Theme.accent
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { batteryPercent = preset.percent }
            Haptics.selection()
        } label: {
            HStack(spacing: 6) {
                Text(preset.label)
                    .font(Theme.bodyM())
                    .foregroundStyle(selected ? Theme.onAccent : Theme.primaryText)
                Text(preset.sublabel)
                    .font(Theme.caption())
                    .foregroundStyle(selected ? Theme.onAccent.opacity(0.75) : tint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
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
        .accessibilityLabel("\(preset.label), \(preset.sublabel)")
        .accessibilityAddTraits(selected ? .isSelected : [])
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
            ProfileSheet(
                userInitial: "E",
                userName: "Eliana Reyes",
                userEmail: "eliana@taya.app",
                appearance: .constant(.auto),
                mirrorLens: .constant(.reflection),
                connectivity: .constant(.ok),
                batteryPercent: .constant(72),
                isCharging: .constant(false),
                notifications: .constant(NotificationPreferences())
            )
        }
}
