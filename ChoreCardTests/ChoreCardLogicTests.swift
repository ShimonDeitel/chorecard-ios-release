import XCTest
import SwiftData
@testable import ChoreCard

/// Tests for the pure scoring/leaderboard engine, the AppModel free-tier limits,
/// the chore template library, and StoreKit wiring.
@MainActor
final class ChoreCardLogicTests: XCTestCase {

    private func memoryModel() -> ModelContainer {
        try! ModelContainer(for: Kid.self, Chore.self, Completion.self, Reward.self,
                            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func model() -> AppModel { AppModel(container: memoryModel()) }

    // MARK: Scoring — points only count when approved

    func testPointsOnlyCountWhenApproved() {
        let kid = UUID()
        let comps = [
            ScoredCompletion(kidID: kid, points: 10, approved: true,  date: .now),
            ScoredCompletion(kidID: kid, points: 5,  approved: false, date: .now),  // pending, ignored
            ScoredCompletion(kidID: kid, points: 7,  approved: true,  date: .now)
        ]
        XCTAssertEqual(Scoring.points(for: kid, in: comps), 17)
    }

    // MARK: Scoring — weekly window

    func testWeeklyPointsExcludeLastWeek() {
        let cal = Calendar.current
        let now = Date()
        let lastWeek = cal.date(byAdding: .day, value: -8, to: now)!
        let kid = UUID()
        let comps = [
            ScoredCompletion(kidID: kid, points: 20, approved: true, date: now),
            ScoredCompletion(kidID: kid, points: 50, approved: true, date: lastWeek)
        ]
        let weekStart = Scoring.startOfWeek(now)
        XCTAssertEqual(Scoring.points(for: kid, in: comps, since: weekStart), 20)
        XCTAssertEqual(Scoring.points(for: kid, in: comps), 70) // all-time still counts both
    }

    // MARK: Leaderboard ranks by weekly points

    func testLeaderboardRanksByWeeklyPoints() {
        let a = UUID(), b = UUID()
        let now = Date()
        let comps = [
            ScoredCompletion(kidID: a, points: 30, approved: true, date: now),
            ScoredCompletion(kidID: b, points: 45, approved: true, date: now)
        ]
        let rows = Scoring.leaderboard(kids: [(a, "Ava"), (b, "Ben")], completions: comps, now: now)
        XCTAssertEqual(rows.first?.name, "Ben")
        XCTAssertEqual(rows.first?.rank, 1)
        XCTAssertEqual(rows.last?.name, "Ava")
        XCTAssertEqual(rows.last?.rank, 2)
    }

    func testPointsNeeded() {
        XCTAssertEqual(Scoring.pointsNeeded(balance: 10, cost: 40), 30)
        XCTAssertEqual(Scoring.pointsNeeded(balance: 50, cost: 40), 0)
    }

    // MARK: Template library loads 30+ family-friendly chores

    func testTemplateLibraryHasAtLeast30() {
        XCTAssertGreaterThanOrEqual(ChoreLibrary.templates.count, 30)
        XCTAssertFalse(ChoreLibrary.categories.isEmpty)
        // Every template has a positive point value and a non-empty title.
        for t in ChoreLibrary.templates {
            XCTAssertFalse(t.title.isEmpty)
            XCTAssertGreaterThan(t.points, 0)
        }
    }

    // MARK: Free-tier limits (defense-in-depth, enforced in AppModel)

    func testFreeTierLimitsOneKidAndThreeChores() {
        let m = model() // no Store attached => not Pro
        XCTAssertNotNil(m.addKid(name: "Ava"))
        XCTAssertNil(m.addKid(name: "Ben"), "free tier allows only one kid")
        XCTAssertEqual(m.kids().count, 1)

        XCTAssertNotNil(m.addChore(title: "A", points: 5))
        XCTAssertNotNil(m.addChore(title: "B", points: 5))
        XCTAssertNotNil(m.addChore(title: "C", points: 5))
        XCTAssertNil(m.addChore(title: "D", points: 5), "free tier allows only 3 chores/week")
        XCTAssertEqual(m.activeChores().count, 3)
    }

    func testCustomRewardBlockedOnFreeTier() {
        let m = model()
        XCTAssertNil(m.addReward(title: "Pizza night", cost: 50, isCustom: true),
                     "custom rewards are a Pro feature")
        // Default (non-custom) rewards were seeded on init.
        XCTAssertFalse(m.rewards().isEmpty)
    }

    // MARK: Completion flow — mark done -> pending -> approve -> points

    func testMarkDoneCreatesPendingAndApproveAwardsPoints() {
        let m = model()
        let kid = m.addKid(name: "Ava")!
        let chore = m.addChore(title: "Make the bed", points: 5)!

        let completion = m.markDone(chore: chore, kid: kid)
        XCTAssertNotNil(completion)
        XCTAssertEqual(m.pendingCompletions().count, 1)
        XCTAssertEqual(m.balance(for: kid), 0, "pending completions award no points")

        // Duplicate pending mark-done is ignored.
        XCTAssertNil(m.markDone(chore: chore, kid: kid))

        m.approve(completion!)
        XCTAssertEqual(m.pendingCompletions().count, 0)
        XCTAssertEqual(m.balance(for: kid), 5, "approval locks in the points")
    }

    func testRejectDiscardsCompletion() {
        let m = model()
        let kid = m.addKid(name: "Ava")!
        let chore = m.addChore(title: "Sweep", points: 10)!
        let c = m.markDone(chore: chore, kid: kid)!
        m.reject(c)
        XCTAssertEqual(m.pendingCompletions().count, 0)
        XCTAssertEqual(m.balance(for: kid), 0)
    }

    // MARK: StoreKit wiring

    func testStoreStartsLockedAtRightPrice() async {
        let store = Store()
        try? await Task.sleep(for: .seconds(0.3))
        XCTAssertEqual(Store.productID, "chorecard_pro_unlock")
        XCTAssertEqual(store.displayPrice, "$0.99")
        XCTAssertFalse(store.isPro, "Pro must start locked")
    }
}
