import SwiftUI

/// Rewards: shows each kid's redeemable balance and the reward catalog. Redemption rules convert
/// points to rewards (cost in points). PRO can add custom rewards.
struct RewardsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showAddReward = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ZStack {
                CCBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        balancesSection
                        catalogSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .id(appModel.lastChangeToken)
                }
            }
            .navigationTitle("Rewards")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        if store.isPro { showAddReward = true } else { showPaywall = true }
                    } label: { Image(systemName: "plus") }
                    .accessibilityIdentifier("add-reward")
                    .accessibilityLabel("Add reward")
                }
            }
            .sheet(isPresented: $showAddReward) { AddRewardSheet() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var balancesSection: some View {
        let kids = appModel.kids()
        return VStack(alignment: .leading, spacing: 12) {
            Text("Point balances").font(.headline)
            if kids.isEmpty {
                EmptyHint(symbol: "person.2",
                          title: "No kids yet",
                          message: "Add a kid on the Home tab to start earning points.")
            } else {
                VStack(spacing: 10) {
                    ForEach(kids) { kid in
                        HStack(spacing: 12) {
                            KidAvatar(name: kid.name, size: 38)
                            Text(kid.name).font(.body.weight(.semibold))
                            Spacer()
                            Text("\(appModel.balance(for: kid)) pts")
                                .font(.headline)
                                .foregroundStyle(Color.ccAccent)
                        }
                        .padding(12)
                        .background(Color.ccCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private var catalogSection: some View {
        let rewards = appModel.rewards()
        let topBalance = appModel.kids().map { appModel.balance(for: $0) }.max() ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reward catalog").font(.headline)
                Spacer()
                if !store.isPro {
                    Text("Pro: custom rewards").font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 10) {
                ForEach(rewards) { reward in
                    RewardRow(reward: reward, topBalance: topBalance)
                }
            }
        }
    }
}

struct RewardRow: View {
    @EnvironmentObject var appModel: AppModel
    let reward: Reward
    let topBalance: Int

    private var affordable: Bool { topBalance >= reward.cost }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: affordable ? "gift.fill" : "gift")
                .font(.title3)
                .foregroundStyle(affordable ? Color.ccAccent : .secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(reward.title).font(.body.weight(.medium))
                Text(affordable ? "Ready to redeem" : "\(Scoring.pointsNeeded(balance: topBalance, cost: reward.cost)) pts to go")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(reward.cost)").font(.headline).foregroundStyle(.secondary)
            Text("pts").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.ccCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .swipeActions(edge: .trailing) {
            if reward.isCustom {
                Button(role: .destructive) {
                    Haptics.warning(); appModel.deleteReward(reward)
                } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }
}

/// PRO: add a custom reward with a points cost.
struct AddRewardSheet: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var cost = 50

    var body: some View {
        NavigationStack {
            Form {
                Section("Reward") {
                    TextField("e.g. Pizza night", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("reward-title-field")
                }
                Section("Cost in points") {
                    Stepper(value: $cost, in: 5...500, step: 5) {
                        HStack { Text("Cost"); Spacer(); Text("\(cost) pts").foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("New reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        if appModel.addReward(title: title, cost: cost, isCustom: true) != nil {
                            Haptics.success()
                        }
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
