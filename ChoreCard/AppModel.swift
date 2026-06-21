import Foundation
import SwiftData
import SwiftUI

/// App state: owns the SwiftData store (fully local on-device persistence), seeds default
/// rewards on first launch, and centralizes every data mutation plus the FREE-tier limits.
///
/// FREE limits (enforced here, defense-in-depth, not just in the UI):
///   - one kid
///   - three ACTIVE chores per week
///   - default rewards only (no custom rewards)
/// PRO removes all of these.
@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    static let freeKidLimit = 1
    static let freeWeeklyChoreLimit = 3

    @Published private(set) var lastChangeToken = UUID()

    init(container: ModelContainer) {
        self.container = container
        seedDefaultRewardsIfNeeded()
        #if DEBUG
        seedIfRequested()
        #endif
    }

    private var isPro: Bool { store?.isPro == true }

    // MARK: Container

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Kid.self, Chore.self, Completion.self, Reward.self])
        // Local-only persistence — no CloudKit, no special capabilities. Falls back to an
        // in-memory store if on-disk creation ever fails so the app always launches.
        let local = ModelConfiguration(schema: schema)
        if let c = try? ModelContainer(for: schema, configurations: local) { return c }
        let mem = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: mem)
    }

    private var ctx: ModelContext { container.mainContext }

    private func bump() { lastChangeToken = UUID() }

    // MARK: Fetch helpers

    func kids() -> [Kid] {
        let d = FetchDescriptor<Kid>(sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)])
        return (try? ctx.fetch(d)) ?? []
    }

    func activeChores() -> [Chore] {
        let d = FetchDescriptor<Chore>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return ((try? ctx.fetch(d)) ?? []).filter { !$0.isArchived }
    }

    func rewards() -> [Reward] {
        let d = FetchDescriptor<Reward>(sortBy: [SortDescriptor(\.cost)])
        return (try? ctx.fetch(d)) ?? []
    }

    func allCompletions() -> [Completion] {
        let d = FetchDescriptor<Completion>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? ctx.fetch(d)) ?? []
    }

    /// Pending (not-yet-approved) completions — the parent approval queue.
    func pendingCompletions() -> [Completion] {
        allCompletions().filter { !$0.approved }
    }

    // MARK: Derived limits

    func canAddKid() -> Bool { isPro || kids().count < Self.freeKidLimit }

    /// Active chores created in the current calendar week count toward the free weekly limit.
    func choresThisWeek(now: Date = .now) -> Int {
        let weekStart = Scoring.startOfWeek(now)
        return activeChores().filter { $0.createdAt >= weekStart }.count
    }

    func canAddChore(now: Date = .now) -> Bool {
        isPro || choresThisWeek(now: now) < Self.freeWeeklyChoreLimit
    }

    func canAddCustomReward() -> Bool { isPro }

    // MARK: Mutations — Kids

    @discardableResult
    func addKid(name: String) -> Kid? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canAddKid() else { return nil }
        let kid = Kid(name: trimmed, sortIndex: kids().count)
        ctx.insert(kid)
        try? ctx.save(); bump()
        return kid
    }

    func renameKid(_ kid: Kid, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        kid.name = trimmed
        try? ctx.save(); bump()
    }

    func deleteKid(_ kid: Kid) {
        ctx.delete(kid)
        try? ctx.save(); bump()
    }

    // MARK: Mutations — Chores

    @discardableResult
    func addChore(title: String, points: Int, category: String = "General", now: Date = .now) -> Chore? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canAddChore(now: now) else { return nil }
        let chore = Chore(title: trimmed, points: max(1, points), category: category)
        ctx.insert(chore)
        try? ctx.save(); bump()
        return chore
    }

    @discardableResult
    func addChore(from template: ChoreTemplate, now: Date = .now) -> Chore? {
        addChore(title: template.title, points: template.points, category: template.category, now: now)
    }

    func archiveChore(_ chore: Chore) {
        chore.isArchived = true
        try? ctx.save(); bump()
    }

    // MARK: Mutations — Completions (kid taps done; parent approves/rejects)

    /// A kid marks a chore done. Creates a PENDING completion. Avoids duplicate pending entries
    /// for the same kid+chore.
    @discardableResult
    func markDone(chore: Chore, kid: Kid) -> Completion? {
        let alreadyPending = (chore.completions ?? []).contains {
            !$0.approved && $0.kid?.id == kid.id
        }
        guard !alreadyPending else { return nil }
        let c = Completion(pointsAwarded: chore.points, choreTitle: chore.title,
                           kid: kid, chore: chore)
        ctx.insert(c)
        try? ctx.save(); bump()
        return c
    }

    /// Parent approves — locks in the points.
    func approve(_ completion: Completion) {
        completion.approved = true
        completion.approvedAt = .now
        try? ctx.save(); bump()
    }

    /// Parent rejects — discards the completion (no points).
    func reject(_ completion: Completion) {
        ctx.delete(completion)
        try? ctx.save(); bump()
    }

    // MARK: Mutations — Rewards

    @discardableResult
    func addReward(title: String, cost: Int, isCustom: Bool) -> Reward? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if isCustom && !canAddCustomReward() { return nil }
        let r = Reward(title: trimmed, cost: max(1, cost), isCustom: isCustom)
        ctx.insert(r)
        try? ctx.save(); bump()
        return r
    }

    func deleteReward(_ reward: Reward) {
        ctx.delete(reward)
        try? ctx.save(); bump()
    }

    // MARK: Scoring bridge

    /// Value-type snapshot of every completion, for the pure `Scoring` engine.
    func scored() -> [ScoredCompletion] {
        allCompletions().compactMap { c in
            guard let kid = c.kid else { return nil }
            return ScoredCompletion(kidID: kid.id, points: c.pointsAwarded,
                                    approved: c.approved, date: c.date)
        }
    }

    func leaderboard(now: Date = .now) -> [LeaderboardRow] {
        Scoring.leaderboard(kids: kids().map { ($0.id, $0.name) },
                            completions: scored(), now: now)
    }

    func balance(for kid: Kid) -> Int {
        Scoring.points(for: kid.id, in: scored())
    }

    // MARK: Seeding

    private func seedDefaultRewardsIfNeeded() {
        let existing = (try? ctx.fetch(FetchDescriptor<Reward>())) ?? []
        guard existing.isEmpty else { return }
        for t in ChoreLibrary.rewards {
            ctx.insert(Reward(title: t.title, cost: t.cost, isCustom: false))
        }
        try? ctx.save()
    }

    /// Erase all on-device data (used by Delete Account).
    func deleteAllData() {
        try? ctx.delete(model: Completion.self)
        try? ctx.delete(model: Chore.self)
        try? ctx.delete(model: Kid.self)
        try? ctx.delete(model: Reward.self)
        try? ctx.save()
        seedDefaultRewardsIfNeeded()
        bump()
    }

    // MARK: DEBUG seeding (compiled out of Release)

    #if DEBUG
    private func seedIfRequested() {
        let env = ProcessInfo.processInfo.environment
        guard env["CHORECARD_SEED"] == "1" else { return }
        guard ((try? ctx.fetch(FetchDescriptor<Kid>()))?.isEmpty ?? true) else { return }

        let names = ["Ava", "Liam", "Mia"]
        var kidsCreated: [Kid] = []
        for (i, n) in names.enumerated() {
            let k = Kid(name: n, sortIndex: i); ctx.insert(k); kidsCreated.append(k)
        }
        let samples = Array(ChoreLibrary.templates.prefix(5))
        for (i, t) in samples.enumerated() {
            let chore = Chore(title: t.title, points: t.points, category: t.category)
            ctx.insert(chore)
            // Some approved, some pending, across the kids.
            let kid = kidsCreated[i % kidsCreated.count]
            let approved = i % 2 == 0
            let c = Completion(approved: approved,
                               approvedAt: approved ? .now : nil,
                               pointsAwarded: t.points, choreTitle: t.title,
                               kid: kid, chore: chore)
            ctx.insert(c)
        }
        try? ctx.save(); bump()
    }
    #endif
}
