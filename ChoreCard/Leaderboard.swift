import Foundation

/// A lightweight, value-type snapshot of one approved completion — used by the pure scoring
/// engine so the leaderboard math can be tested without SwiftData.
struct ScoredCompletion {
    let kidID: UUID
    let points: Int
    let approved: Bool
    let date: Date
}

/// One row in the leaderboard.
struct LeaderboardRow: Identifiable {
    let kidID: UUID
    let name: String
    let weeklyPoints: Int
    let totalPoints: Int
    var rank: Int = 0
    var id: UUID { kidID }
}

/// Pure, deterministic scoring. No SwiftData, no dates-of-now hidden inside — the caller passes
/// `now` so tests are reproducible.
enum Scoring {

    /// Inclusive start of the current week (respecting the calendar's first weekday).
    static func startOfWeek(_ now: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
    }

    /// Total APPROVED points earned by a kid since `since` (defaults to all time).
    static func points(for kidID: UUID, in completions: [ScoredCompletion],
                       since: Date = .distantPast) -> Int {
        completions
            .filter { $0.kidID == kidID && $0.approved && $0.date >= since }
            .reduce(0) { $0 + $1.points }
    }

    /// Builds a ranked leaderboard. Ties share neither order nor a rank jump issue: rows are
    /// sorted by weekly points (desc), then total (desc), then name; ranks are 1-based by position.
    static func leaderboard(kids: [(id: UUID, name: String)],
                            completions: [ScoredCompletion],
                            now: Date,
                            calendar: Calendar = .current) -> [LeaderboardRow] {
        let weekStart = startOfWeek(now, calendar: calendar)
        var rows = kids.map { kid in
            LeaderboardRow(
                kidID: kid.id,
                name: kid.name,
                weeklyPoints: points(for: kid.id, in: completions, since: weekStart),
                totalPoints: points(for: kid.id, in: completions)
            )
        }
        rows.sort {
            if $0.weeklyPoints != $1.weeklyPoints { return $0.weeklyPoints > $1.weeklyPoints }
            if $0.totalPoints != $1.totalPoints { return $0.totalPoints > $1.totalPoints }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        for i in rows.indices { rows[i].rank = i + 1 }
        return rows
    }

    /// How many MORE points a kid needs to afford a reward (0 if already affordable).
    static func pointsNeeded(balance: Int, cost: Int) -> Int {
        max(0, cost - balance)
    }
}
