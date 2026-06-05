import SwiftUI

/// Push-detail screen for per-category notification opt-ins, reached from
/// the Profile sheet's "Notifications" row. Two sections — the four
/// content categories Taya generates, and a separate row for operational
/// device pings — so the user can dial back nudges without losing battery
/// or sync alerts.
struct NotificationsSubmenu: View {
    @Binding var notifications: NotificationPreferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                actionRow
                contentSection
                deviceAlertsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.pageContentTopInset)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: - Header

    /// Back button (40pt glass circle, left-aligned) plus a centered SF
    /// Pro title, matching the chrome pattern used by ChatDetailSheet.
    /// The system nav bar is hidden so the toolbar's own Liquid Glass
    /// background doesn't double-stack on top of our glass material.
    private var actionRow: some View {
        ZStack {
            Text("Notifications")
                .font(Theme.titleM())
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .padding(.horizontal, 56)
            HStack {
                backButton
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var backButton: some View {
        Button {
            Haptics.tap()
            dismiss()
        } label: {
            Image(systemName: "chevron.backward")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .tayaGlassCard(in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    // MARK: - Content notifications

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Categories")
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            Text("Pick which nudges Taya is allowed to send.")
                .font(Theme.caption())
                .foregroundStyle(Theme.tertiaryText)

            VStack(spacing: 8) {
                ForEach(NotificationCategory.content) { category in
                    row(for: category)
                }
            }
            .padding(.top, 2)
        }
    }

    private var deviceAlertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Device alerts")
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            Text("Operational pings about your necklace — low battery, sync issues, disconnects.")
                .font(Theme.caption())
                .foregroundStyle(Theme.tertiaryText)

            row(for: .deviceAlerts)
                .padding(.top, 2)
        }
    }

    /// One toggle row in the glass capsule style shared with the rest of
    /// the Profile surfaces.
    private func row(for category: NotificationCategory) -> some View {
        Toggle(isOn: binding(for: category)) {
            HStack(spacing: 10) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 20)
                Text(category.label)
                    .font(Theme.bodyM())
                    .foregroundStyle(Theme.primaryText)
            }
        }
        .tint(Theme.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 0.75)
        )
        .onChange(of: binding(for: category).wrappedValue) { _, _ in
            Haptics.selection()
        }
    }

    private func binding(for category: NotificationCategory) -> Binding<Bool> {
        switch category {
        case .tasks:        return $notifications.tasks
        case .reflections:  return $notifications.reflections
        case .suggestions:  return $notifications.suggestions
        case .resurfaced:   return $notifications.resurfaced
        case .deviceAlerts: return $notifications.deviceAlerts
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsSubmenu(notifications: .constant(NotificationPreferences()))
    }
    .presentationBackground(Theme.backgroundGradient)
}
