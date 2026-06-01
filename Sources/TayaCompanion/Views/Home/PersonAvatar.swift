import SwiftUI

struct PersonAvatar: View {
    let person: Person
    let onTap: () -> Void

    private var initial: String {
        String(person.name.prefix(1))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(initial)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 56, height: 56)
                    .tayaGlassCard(in: Circle())
                Text(person.name)
                    .font(Theme.caption())
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
            }
            .frame(width: 72)
        }
        .buttonStyle(.plain)
    }
}
