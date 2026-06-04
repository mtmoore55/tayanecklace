import SwiftUI

/// Configures and previews a Markdown export of moments, then hands off to
/// the native share sheet. Filter by day (defaults to everything), optionally
/// narrow by people or places; the count updates live so the user knows
/// exactly what they're sending before it leaves the app.
struct MomentsExportSheet: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDays: Set<Date> = []
    @State private var selectedPeople: Set<UUID> = []
    @State private var selectedPlaces: Set<String> = []
    @State private var didInit = false

    private let cal = Calendar.current

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    countPreview
                    daysSection
                    if !store.people.isEmpty { peopleSection }
                    if !store.places.isEmpty { placesSection }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 130)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            exportButton
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
        .onAppear {
            guard !didInit else { return }
            selectedDays = Set(availableDays.map(\.day))
            didInit = true
        }
    }

    // MARK: - Header & live preview

    private var header: some View {
        Text("Export")
            .font(Theme.displayXL())
            .foregroundStyle(Theme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var countPreview: some View {
        let n = filtered.count
        let days = dayCount
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(n) \(n == 1 ? "moment" : "moments")")
                .font(Theme.titleL())
                .foregroundStyle(Theme.primaryText)
            Text(n == 0
                 ? "Nothing selected"
                 : "across \(days) \(days == 1 ? "day" : "days") · exported as Markdown")
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: - Filter sections

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Days", action: (allDaysSelected ? "Clear" : "Select all", toggleAllDays))
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(availableDays, id: \.day) { item in
                    SelectableChip(
                        text: "\(RelativeDay.sectionLabel(from: item.day)) · \(item.count)",
                        isSelected: selectedDays.contains(item.day)
                    ) {
                        selectedDays.formSymmetricDifference([item.day])
                    }
                }
            }
        }
    }

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("People", subtitle: "Optional — narrow to moments mentioning")
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(store.people) { person in
                    SelectableChip(
                        text: person.name,
                        systemImage: "person.circle",
                        isSelected: selectedPeople.contains(person.id)
                    ) {
                        selectedPeople.formSymmetricDifference([person.id])
                    }
                }
            }
        }
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Places", subtitle: "Optional — narrow to moments at")
            FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(store.places, id: \.self) { place in
                    SelectableChip(
                        text: place,
                        systemImage: "location.fill",
                        isSelected: selectedPlaces.contains(place)
                    ) {
                        selectedPlaces.formSymmetricDifference([place])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(
        _ title: String,
        subtitle: String? = nil,
        action: (label: String, run: () -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Theme.titleS())
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                if let action {
                    Button(action.label, action: action.run)
                        .font(Theme.bodyS())
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(Theme.bodyS())
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
    }

    // MARK: - Export action

    private var exportButton: some View {
        ShareLink(
            item: MomentExport.markdown(for: filtered, store: store),
            subject: Text("Taya Moments"),
            preview: SharePreview("Taya Moments — \(filtered.count) \(filtered.count == 1 ? "moment" : "moments")")
        ) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                Text("Export \(filtered.count) \(filtered.count == 1 ? "moment" : "moments")")
            }
            .font(Theme.titleS())
            .foregroundStyle(Theme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .tayaGlassCard(in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(filtered.isEmpty)
        .opacity(filtered.isEmpty ? 0.45 : 1)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Data

    private var availableDays: [(day: Date, count: Int)] {
        let buckets = Dictionary(grouping: store.activeMoments) { cal.startOfDay(for: $0.createdAt) }
        return buckets.keys.sorted(by: >).map { (day: $0, count: buckets[$0]!.count) }
    }

    private var filtered: [Moment] {
        store.activeMoments
            .filter { moment in
                guard selectedDays.contains(cal.startOfDay(for: moment.createdAt)) else { return false }
                if !selectedPeople.isEmpty {
                    let ids = Set(store.people(in: moment.id).map(\.id))
                    if ids.isDisjoint(with: selectedPeople) { return false }
                }
                if !selectedPlaces.isEmpty {
                    let matches = selectedPlaces.contains { place in
                        moment.title.localizedCaseInsensitiveContains(place)
                            || moment.polishedSummary.localizedCaseInsensitiveContains(place)
                            || moment.rawTranscript.localizedCaseInsensitiveContains(place)
                    }
                    if !matches { return false }
                }
                return true
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var dayCount: Int {
        Set(filtered.map { cal.startOfDay(for: $0.createdAt) }).count
    }

    private var allDaysSelected: Bool {
        selectedDays.count == availableDays.count
    }

    // MARK: - Mutation helpers

    private func toggleAllDays() {
        selectedDays = allDaysSelected ? [] : Set(availableDays.map(\.day))
    }
}

/// A pill that toggles between glass (off) and accent-filled (on). Local to
/// the export sheet — the shared `Chip` has no selected state.
private struct SelectableChip: View {
    let text: String
    var systemImage: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) { label }
            .buttonStyle(.plain)
    }

    @ViewBuilder
    private var label: some View {
        let base = HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .regular))
            }
            Text(text)
                .font(Theme.bodyS())
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .foregroundStyle(isSelected ? Theme.onAccent : Theme.primaryText)

        if isSelected {
            base.background(Capsule(style: .continuous).fill(Theme.accent))
        } else {
            base.tayaGlassCard(in: Capsule(style: .continuous))
        }
    }
}
