import SwiftUI
import TayaIntelligence

struct UserView: View {
    @Environment(\.gesturePhase) private var gesturePhase

    private let userName = "Eliza"
    private let userEmail = "eliza@example.com"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                identityCard
                section(eyebrow: "Account") {
                    settingsRows(items: [
                        .init(systemImage: "person.crop.circle", title: "Edit profile"),
                        .init(systemImage: "creditcard", title: "Subscription"),
                        .init(systemImage: "icloud", title: "Sync & backup"),
                    ])
                }
                section(eyebrow: "Preferences") {
                    settingsRows(items: [
                        .init(systemImage: "bell", title: "Notifications"),
                        .init(systemImage: "lock", title: "Privacy"),
                        .init(systemImage: "mic", title: "Capture preferences"),
                    ])
                }
                section(eyebrow: "About") {
                    settingsRows(items: [
                        .init(systemImage: "questionmark.circle", title: "Help & support"),
                        .init(systemImage: "doc.text", title: "Terms & privacy"),
                        .init(systemImage: "arrow.right.square", title: "Sign out", isDestructive: true),
                    ])
                }
                versionFooter
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.pageContentTopInset)
            .padding(.bottom, Theme.pageContentBottomInset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDisabled(gesturePhase == .horizontalSwipe)
    }

    // MARK: - Pieces

    private var identityCard: some View {
        Card {
            HStack(spacing: 14) {
                Text(String(userName.prefix(1)))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(TayaColors.oxfordBlue)
                    .frame(width: 56, height: 56)
                    .background(TayaColors.skyBlue.opacity(0.32), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(userName)
                        .font(Theme.cardTitle())
                    Text(userEmail)
                        .font(Theme.caption())
                        .foregroundStyle(Theme.secondaryText)
                }
                Spacer()
            }
        }
    }

    private struct SettingsRowItem {
        let systemImage: String
        let title: String
        var isDestructive: Bool = false
    }

    private func settingsRows(items: [SettingsRowItem]) -> some View {
        Card(padding: 4) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.title) { index, item in
                    HStack(spacing: 14) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(item.isDestructive ? Color.red : TayaColors.oxfordBlue)
                            .frame(width: 24)
                        Text(item.title)
                            .font(Theme.body())
                            .foregroundStyle(item.isDestructive ? Color.red : Theme.primaryText)
                        Spacer()
                        if !item.isDestructive {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    if index < items.count - 1 {
                        Divider().padding(.leading, 50)
                    }
                }
            }
        }
    }

    private var versionFooter: some View {
        Text("Taya · v0.1 prototype")
            .font(Theme.caption())
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 8)
    }

    private func section<Content: View>(eyebrow: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(Theme.eyebrow())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }
}

#Preview {
    UserView()
        .environment(DataStore.seeded(now: Date()))
}
