import Foundation
import SwiftData

// MARK: - SwiftData models
//
// All data is stored locally on-device. All properties have defaults and relationships are
// optional with explicit inverses. Kids are stored by NAME only — no kid accounts, no PII,
// no photos.

/// A child in the household. Identified only by a display name.
@Model
final class Kid {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now
    var sortIndex: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \Completion.kid)
    var completions: [Completion]? = []

    init(id: UUID = UUID(), name: String = "", createdAt: Date = .now, sortIndex: Int = 0) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortIndex = sortIndex
    }
}

/// A chore the parent has assigned, with its point value.
@Model
final class Chore {
    var id: UUID = UUID()
    var title: String = ""
    var points: Int = 5
    var category: String = "General"
    var createdAt: Date = Date.now
    var isArchived: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Completion.chore)
    var completions: [Completion]? = []

    init(id: UUID = UUID(), title: String = "", points: Int = 5,
         category: String = "General", createdAt: Date = .now, isArchived: Bool = false) {
        self.id = id
        self.title = title
        self.points = points
        self.category = category
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}

/// A kid tapping "done" on a chore. Starts pending; the parent approves (or rejects) it.
/// `pointsAwarded` is snapshotted at completion time so later edits to the chore don't
/// retroactively change history.
@Model
final class Completion {
    var id: UUID = UUID()
    var date: Date = Date.now
    var approved: Bool = false
    var approvedAt: Date? = nil
    var pointsAwarded: Int = 0
    var choreTitle: String = ""      // denormalized snapshot for history/PDF

    var kid: Kid? = nil
    var chore: Chore? = nil

    init(id: UUID = UUID(), date: Date = .now, approved: Bool = false,
         approvedAt: Date? = nil, pointsAwarded: Int = 0, choreTitle: String = "",
         kid: Kid? = nil, chore: Chore? = nil) {
        self.id = id
        self.date = date
        self.approved = approved
        self.approvedAt = approvedAt
        self.pointsAwarded = pointsAwarded
        self.choreTitle = choreTitle
        self.kid = kid
        self.chore = chore
    }
}

/// A reward a kid can redeem points for (e.g. "Movie night - 50 pts").
@Model
final class Reward {
    var id: UUID = UUID()
    var title: String = ""
    var cost: Int = 25
    var createdAt: Date = Date.now
    var isCustom: Bool = false

    init(id: UUID = UUID(), title: String = "", cost: Int = 25,
         createdAt: Date = .now, isCustom: Bool = false) {
        self.id = id
        self.title = title
        self.cost = cost
        self.createdAt = createdAt
        self.isCustom = isCustom
    }
}
