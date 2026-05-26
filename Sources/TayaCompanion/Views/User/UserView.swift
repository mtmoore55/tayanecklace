import SwiftUI
import PhotosUI
import TayaIntelligence
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct UserView: View {
    @Environment(\.gesturePhase) private var gesturePhase

    private let userName = "Eliza"
    private let userEmail = "eliza@example.com"

    @State private var avatarSelection: PhotosPickerItem?
    @State private var avatarImage: Image?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                identityHeader
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

    private var identityHeader: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $avatarSelection, matching: .images, photoLibrary: .shared()) {
                avatarView
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change profile photo")

            VStack(spacing: 4) {
                Text(userName)
                    .font(Theme.displayMedium())
                    .foregroundStyle(Theme.primaryText)
                Text(userEmail)
                    .font(Theme.bodyL())
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .onChange(of: avatarSelection) { _, newItem in
            guard let newItem else { return }
            Task { await loadAvatar(from: newItem) }
        }
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(TayaColors.skyBlue.opacity(0.32))

            if let avatarImage {
                avatarImage
                    .resizable()
                    .scaledToFill()
            } else {
                Text(String(userName.prefix(1)))
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(TayaColors.oxfordBlue)
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "camera.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Theme.accent, in: Circle())
                .overlay(Circle().stroke(Theme.background, lineWidth: 3))
        }
    }

    private func loadAvatar(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return }
        let loaded = Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return }
        let loaded = Image(nsImage: nsImage)
        #else
        let loaded: Image? = nil
        guard let loaded else { return }
        #endif
        await MainActor.run {
            avatarImage = loaded
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
                            .foregroundStyle(item.isDestructive ? Color.red : Theme.accent)
                            .frame(width: 24)
                        Text(item.title)
                            .font(Theme.bodyL())
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
                .font(Theme.micro())
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
