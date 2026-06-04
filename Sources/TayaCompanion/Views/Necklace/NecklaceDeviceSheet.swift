import SwiftUI

/// Device-details bottom sheet opened from the "Connected" pill in the
/// necklace hardware area. Holds the technical specifics we keep off the
/// main hardware screen so it stays calm and non-technical.
struct NecklaceDeviceSheet: View {
    let ambient: AmbientState

    private let firmware = "v1.2.3"
    private let serial = "TY-A1F7"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    connectionCard
                    deviceCard
                }
                .padding(20)
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Necklace")
            #if os(iOS)
            .toolbarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
        // Opaque presentation background. Liquid Glass cards sample the
        // sheet's backdrop, not just the inner SwiftUI background — at a
        // medium detent the default translucent sheet surface lets the
        // dimmed presenting content bleed through, so the same card reads
        // darker than at the large detent. A flat opaque surface makes the
        // glass identical at every detent.
        .presentationBackground(Theme.backgroundGradient)
    }

    private var connectionCard: some View {
        sectionFrame(eyebrow: "Connection") {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    statusRow(icon: statusIcon, title: "Status", value: connectionStatus, valueTint: statusTint)
                    divider
                    statusRow(icon: batteryIcon, title: "Battery", value: batteryValue, valueTint: batteryTint)
                    divider
                    statusRow(icon: "wave.3.right", title: "Signal", value: signalLabel)
                    divider
                    statusRow(icon: "clock.arrow.circlepath", title: "Last synced", value: lastSynced)
                }
            }
        }
    }

    private var batteryIcon: String {
        batterySystemImage(forPercent: ambient.necklaceBattery, isCharging: ambient.isCharging)
    }

    private var batteryValue: String {
        let percent = "\(ambient.necklaceBattery)%"
        switch ambient.batteryDisplayState {
        case .charging: return "\(percent) · Charging"
        case .critical: return "\(percent) · Critical"
        case .low:      return "\(percent) · Low"
        case .full, .healthy: return percent
        }
    }

    private var batteryTint: Color {
        switch ambient.batteryDisplayState {
        case .low, .critical: return TayaColors.warningAmber
        case .charging, .full, .healthy: return Theme.secondaryText
        }
    }

    private var deviceCard: some View {
        sectionFrame(eyebrow: "Device") {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    statusRow(icon: "cpu", title: "Firmware", value: firmware)
                    divider
                    statusRow(icon: "number", title: "Serial", value: serial)
                }
            }
        }
    }

    private var connectionStatus: String {
        switch ambient.connectivity {
        case .necklaceUnreachable: return "Disconnected"
        case .syncFailed:          return "Sync error"
        case .networkUnreachable, .ok:
            if case .syncing(let c, let t) = ambient.sync { return "Syncing \(c) of \(t)" }
            return "Connected"
        }
    }

    private var statusIcon: String {
        switch ambient.connectivity {
        case .necklaceUnreachable: return "bolt.horizontal.circle"
        case .syncFailed:          return "exclamationmark.triangle"
        case .networkUnreachable, .ok: return "checkmark.circle"
        }
    }

    private var statusTint: Color {
        switch ambient.connectivity {
        case .necklaceUnreachable, .syncFailed: return TayaColors.warningAmber
        case .networkUnreachable, .ok:          return Theme.secondaryText
        }
    }

    private var signalLabel: String {
        ambient.connectivity == .necklaceUnreachable ? "—" : "Strong"
    }

    private var lastSynced: String {
        if ambient.sync.isActive { return "Syncing now" }
        guard let last = ambient.lastSyncedAt else { return "—" }
        let interval = Date().timeIntervalSince(last)
        if interval < 60 { return "Just now" }
        return Self.relativeFormatter.localizedString(for: last, relativeTo: Date())
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    private var divider: some View {
        Divider().padding(.leading, 50).overlay(Theme.cardStroke.opacity(0.5))
    }

    private func statusRow(
        icon: String,
        title: String,
        value: String,
        valueTint: Color = Theme.secondaryText
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(valueTint == Theme.secondaryText ? Theme.accent : valueTint)
                .frame(width: 24)
            Text(title)
                .font(Theme.bodyL())
                .foregroundStyle(Theme.primaryText)
            Spacer()
            Text(value)
                .font(Theme.bodyL())
                .foregroundStyle(valueTint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func sectionFrame<Content: View>(eyebrow: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NecklaceDeviceSheet(ambient: .mock)
        }
}
