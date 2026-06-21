import SwiftUI

/// Home: the weekly leaderboard up top, then today's active chores. From here the parent
/// assigns a new chore or marks a chore done for a kid.
struct DashboardView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showAssign = false
    @State private var showPaywall = false
    @State private var showAddKid = false
    @State private var markTarget: Chore?

    var body: some View {
        NavigationStack {
            ZStack {
                CCBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        leaderboardSection
                        choresSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    // Re-render whenever data changes.
                    .id(appModel.lastChangeToken)
                }
            }
            .navigationTitle("Chore Card")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        if appModel.canAddChore() { showAssign = true } else { showPaywall = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("assign-chore")
                    .accessibilityLabel("Assign chore")
                }
            }
            .sheet(isPresented: $showAssign) { AssignChoreView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showAddKid) { AddKidSheet() }
            .sheet(item: $markTarget) { chore in MarkDoneSheet(chore: chore) }
        }
    }

    // MARK: Leaderboard

    private var leaderboardSection: some View {
        let rows = appModel.leaderboard()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("This week", systemImage: "trophy.fill")
                    .font(.headline)
                Spacer()
                Button {
                    Haptics.tap()
                    if appModel.canAddKid() { showAddKid = true } else { showPaywall = true }
                } label: {
                    Label("Add kid", systemImage: "person.badge.plus")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityIdentifier("add-kid")
            }

            if rows.isEmpty {
                EmptyHint(symbol: "person.2",
                          title: "Add your first kid",
                          message: "Add a name to start tracking points and chores.")
            } else {
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        LeaderboardRowView(row: row)
                    }
                }
            }
        }
    }

    // MARK: Chores

    private var choresSection: some View {
        let chores = appModel.activeChores()
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Today's chores", systemImage: "checklist")
                    .font(.headline)
                Spacer()
                if !store.isPro {
                    Text("\(appModel.choresThisWeek())/\(AppModel.freeWeeklyChoreLimit) this week")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if chores.isEmpty {
                EmptyHint(symbol: "checklist",
                          title: "No chores yet",
                          message: "Tap the plus button to assign a chore from the template library.")
            } else {
                VStack(spacing: 10) {
                    ForEach(chores) { chore in
                        ChoreRowView(chore: chore) {
                            Haptics.tap(); markTarget = chore
                        }
                    }
                }
            }

            Button {
                Haptics.tap()
                if appModel.canAddChore() { showAssign = true } else { showPaywall = true }
            } label: {
                Label("Assign a chore", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .softButton()
            .padding(.top, 4)
        }
    }
}

// MARK: - Rows

struct LeaderboardRowView: View {
    let row: LeaderboardRow
    var body: some View {
        HStack(spacing: 14) {
            Text("\(row.rank)")
                .font(.headline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            KidAvatar(name: row.name, rank: row.rank)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).font(.body.weight(.semibold))
                Text("\(row.totalPoints) pts total").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            PointsBadge(points: row.weeklyPoints, prefix: "+")
        }
        .padding(12)
        .background(Color.ccCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ChoreRowView: View {
    @EnvironmentObject var appModel: AppModel
    let chore: Chore
    let onMarkDone: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(chore.title).font(.body.weight(.medium))
                Text(chore.category).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            PointsBadge(points: chore.points, prefix: "+")
            Button(action: onMarkDone) {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.ccAccent, in: Circle())
            }
            .accessibilityLabel("Mark \(chore.title) done")
        }
        .padding(12)
        .background(Color.ccCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Haptics.warning(); appModel.archiveChore(chore)
            } label: { Label("Remove", systemImage: "archivebox") }
        }
    }
}

// MARK: - Small sheets

/// Pick which kid completed a chore (skips the picker when there's only one kid).
struct MarkDoneSheet: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    let chore: Chore

    var body: some View {
        NavigationStack {
            List {
                Section("Who did \"\(chore.title)\"?") {
                    ForEach(appModel.kids()) { kid in
                        Button {
                            appModel.markDone(chore: chore, kid: kid)
                            Haptics.success(); dismiss()
                        } label: {
                            HStack {
                                KidAvatar(name: kid.name, size: 32)
                                Text(kid.name)
                                Spacer()
                                Image(systemName: "checkmark.circle")
                            }
                        }
                        .tint(.primary)
                    }
                    if appModel.kids().isEmpty {
                        Text("Add a kid first.").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Mark done")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

/// Add a kid by name only — no accounts, no PII.
struct AddKidSheet: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Kid's name") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("kid-name-field")
                }
            }
            .navigationTitle("Add kid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        if appModel.addKid(name: name) != nil { Haptics.success() }
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(220)])
    }
}
