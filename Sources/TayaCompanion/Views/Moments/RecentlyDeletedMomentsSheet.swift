import SwiftUI

/// Recently Deleted — soft-deleted moments awaiting purge. Mirrors the
/// shape of `RecentlyDeletedTasksSheet`; rows can be restored or
/// permanently deleted, and items disappear automatically 30 days after
/// deletion (see `DataStore.purgeExpiredDeletedMoments`).
struct RecentlyDeletedMomentsSheet: View {
    @Environment(DataStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var confirmDeleteAll: Bool = false
    @State private var pendingDelete: Moment?

    var body: some View {
        let groups = store.recentlyDeletedMomentsGroupedByDay()
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                actionRow(hasAny: !groups.isEmpty)
                titleRow
                content(groups: groups)
            }
            .padding(.horizontal, 20)
            .padding(.top, Theme.pageContentTopInset)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.backgroundGradient)
        .onAppear { store.purgeExpiredDeletedMoments() }
        .confirmationDialog(
            "Delete all recently deleted moments?",
            isPresented: $confirmDeleteAll,
            titleVisibility: .visible
        ) {
            Button("Delete all", role: .destructive) {
                withAnimation(.snappy) {
                    for moment in store.recentlyDeletedMomentsGroupedByDay().flatMap(\.moments) {
                        store.permanentlyDeleteMoment(moment)
                    }
                }
                Haptics.commit()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes them for good. It can't be undone.")
        }
        .confirmationDialog(
            "Delete this moment permanently?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { moment in
            Button("Delete permanently", role: .destructive) {
                withAnimation(.snappy) { store.permanentlyDeleteMoment(moment) }
                Haptics.commit()
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("It won't be recoverable after this.")
        }
    }

    // MARK: - Header

    private func actionRow(hasAny: Bool) -> some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Menu {
                Button(role: .destructive) {
                    Haptics.warning()
                    confirmDeleteAll = true
                } label: {
                    Label("Delete all", systemImage: "trash")
                }
                .disabled(!hasAny)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .tayaGlassCard(in: Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("More actions")
        }
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recently Deleted")
                .font(Theme.greeting())
                .foregroundStyle(Theme.primaryText)
                .lineSpacing(-10)
            Text("Moments here are removed after 30 days.")
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - List

    @ViewBuilder
    private func content(groups: [MomentDayGroup]) -> some View {
        if groups.isEmpty {
            Text("Nothing here")
                .font(Theme.bodyM())
                .foregroundStyle(Theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 72)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(groups) { group in
                    daySection(group: group)
                }
            }
        }
    }

    private func daySection(group: MomentDayGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(label: dayLabel(group.day), trailing: retentionLabel(for: group.day))
            Card(padding: 4) {
                VStack(spacing: 0) {
                    ForEach(Array(group.moments.enumerated()), id: \.element.id) { index, moment in
                        deletedRow(moment)
                            .padding(.horizontal, 12)
                            .contextMenu { rowMenu(moment) }
                            .swipeActions(
                                trailing: [
                                    SwipeAction(
                                        label: "Delete",
                                        systemImage: "trash",
                                        tint: .red,
                                        role: .destructive,
                                        action: {
                                            Haptics.warning()
                                            pendingDelete = moment
                                        }
                                    )
                                ],
                                leading: [
                                    SwipeAction(
                                        label: "Restore",
                                        systemImage: "arrow.uturn.backward",
                                        tint: TayaColors.skyBlue,
                                        action: {
                                            Haptics.success()
                                            withAnimation(.snappy) { store.restoreMoment(moment) }
                                        }
                                    )
                                ]
                            )
                        if index < group.moments.count - 1 {
                            Divider()
                                .padding(.horizontal, 12)
                                .overlay(Theme.glassStroke.opacity(0.5))
                        }
                    }
                }
            }
        }
    }

    private func deletedRow(_ moment: Moment) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: moment.source == .necklace ? "circle.dotted.circle" : "iphone")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Theme.tertiaryText)
                .frame(width: 22, alignment: .center)
            Text(moment.title)
                .font(Theme.bodyL())
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(moment.createdAt.formatted(date: .omitted, time: .shortened))
                .font(Theme.caption())
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func rowMenu(_ moment: Moment) -> some View {
        Button {
            Haptics.success()
            withAnimation(.snappy) { store.restoreMoment(moment) }
        } label: {
            Label("Restore", systemImage: "arrow.uturn.backward.circle")
        }
        Button(role: .destructive) {
            Haptics.warning()
            pendingDelete = moment
        } label: {
            Label("Delete permanently", systemImage: "trash")
        }
    }

    // MARK: - Section header

    private func sectionHeader(label: String, trailing: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(Theme.micro())
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(Theme.micro())
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.tertiaryText)
            }
        }
    }

    // MARK: - Labels

    private func dayLabel(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func retentionLabel(for day: Date) -> String? {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: day), to: cal.startOfDay(for: Date())).day ?? 0
        let remaining = 30 - days
        guard remaining < 30 else { return nil }
        if remaining <= 0 { return "Removing today" }
        if remaining == 1 { return "1 day left" }
        return "\(remaining) days left"
    }
}
