import SwiftUI
import TayaIntelligence

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
                    statusRow(icon: "checkmark.circle", title: "Status", value: connectionStatus)
                    divider
                    statusRow(icon: "wave.3.right", title: "Signal", value: "Strong")
                    divider
                    statusRow(icon: "clock.arrow.circlepath", title: "Last synced", value: lastSynced)
                }
            }
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
        if case .syncing(let c, let t) = ambient.sync { return "Syncing \(c) of \(t)" }
        return "Connected"
    }

    private var lastSynced: String {
        if ambient.sync.isActive { return "Syncing now" }
        return "Just now"
    }

    private var divider: some View {
        Divider().padding(.leading, 50).overlay(Theme.cardStroke.opacity(0.5))
    }

    private func statusRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            Text(title)
                .font(Theme.bodyL())
                .foregroundStyle(Theme.primaryText)
            Spacer()
            Text(value)
                .font(Theme.bodyL())
                .foregroundStyle(Theme.secondaryText)
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
