import SwiftUI

struct ThemeDetailSheet: View {
    let theme: String
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var presentedMoment: MomentRoute?
    @State private var askTayaQuery: String?

    var body: some View {
        content
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .presentationDragIndicator(.visible)
            .presentationBackground(Theme.backgroundGradient)
        .sheet(item: $presentedMoment) { route in
            MomentDetailView(momentID: route.id).environment(store)
        }
        .sheet(item: Binding(
            get: { askTayaQuery.map { AskTayaSeed(query: $0) } },
            set: { askTayaQuery = $0?.query }
        )) { seed in
            QuickAskTayaSheet(initialDraft: seed.query)
        }
    }

    private var content: some View {
        let moments = store.moments(taggedWith: theme)
        let people = store.people(forTheme: theme)

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header(momentCount: moments.count)
                if !people.isEmpty {
                    peopleSection(people: people)
                }
                if !moments.isEmpty {
                    momentsSection(moments: moments)
                } else {
                    emptyState
                }
                askTayaCTA
            }
            .padding(.horizontal, 20)
            .padding(.top, 40)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Header

    private func header(momentCount: Int) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "tag.fill")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Theme.accent)
                .frame(width: 96, height: 96)
                .tayaGlassCard(in: Circle())

            VStack(spacing: 4) {
                Text(theme)
                    .font(Theme.titleL())
                    .foregroundStyle(Theme.primaryText)
                Text(subtitle(momentCount: momentCount))
                    .font(Theme.bodyS())
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func subtitle(momentCount: Int) -> String {
        switch momentCount {
        case 0: return "No moments tagged"
        case 1: return "1 moment tagged"
        default: return "\(momentCount) moments tagged"
        }
    }

    // MARK: - Sections

    private func peopleSection(people: [Person]) -> some View {
        sectionFrame(eyebrow: "Who shows up here") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(people) { person in
                        PersonAvatar(person: person) {
                            // Reuse the chat seed slot to navigate up
                            // and present the person — for now, no-op:
                            // tapping should bubble up to root. Demo-only.
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }

    private func momentsSection(moments: [Moment]) -> some View {
        sectionFrame(eyebrow: "Moments") {
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(moments.enumerated()), id: \.element.id) { i, moment in
                        Button {
                            presentedMoment = MomentRoute(id: moment.id)
                        } label: {
                            MomentRow(moment: moment)
                                .padding(.horizontal, 12)
                        }
                        .buttonStyle(.plain)
                        if i < moments.count - 1 {
                            Divider().padding(.horizontal, 12)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        Card {
            Text("No moments are tagged #\(theme) yet.")
                .font(Theme.bodyL())
                .foregroundStyle(Theme.secondaryText)
        }
    }

    private var askTayaCTA: some View {
        Button {
            askTayaQuery = "What have I captured about \(theme)?"
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("Ask Taya about \(theme)")
                    .font(Theme.bodyL().weight(.semibold))
            }
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule(style: .continuous).fill(Theme.accent))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
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

private struct AskTayaSeed: Identifiable {
    let id = UUID()
    let query: String
}

#Preview {
    ThemeDetailSheet(theme: "recommendation")
        .environment(DataStore.seeded(now: Date()))
}
