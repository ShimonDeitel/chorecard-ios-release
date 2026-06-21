import Foundation

/// A bundled, parent-pickable chore template. Original, family-friendly content loaded at launch.
struct ChoreTemplate: Codable, Identifiable, Hashable {
    var title: String
    var points: Int
    var category: String
    var id: String { "\(category)::\(title)" }
}

/// A bundled reward template.
struct RewardTemplate: Codable, Identifiable, Hashable {
    var title: String
    var cost: Int
    var id: String { title }
}

/// Loads the bundled JSON datasets once at launch. Falls back to a small built-in set if the
/// resource is ever missing, so the picker is never empty.
enum ChoreLibrary {
    static let templates: [ChoreTemplate] = load("chore_templates", fallback: builtInChores)
    static let rewards: [RewardTemplate] = load("default_rewards", fallback: builtInRewards)

    /// Distinct categories in template order, for the filter row.
    static var categories: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for t in templates where !seen.contains(t.category) {
            seen.insert(t.category)
            ordered.append(t.category)
        }
        return ordered
    }

    private static func load<T: Decodable>(_ name: String, fallback: [T]) -> [T] {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([T].self, from: data),
              !decoded.isEmpty
        else { return fallback }
        return decoded
    }

    private static let builtInChores: [ChoreTemplate] = [
        ChoreTemplate(title: "Make the bed", points: 5, category: "Bedroom"),
        ChoreTemplate(title: "Take out the trash", points: 10, category: "Cleaning"),
        ChoreTemplate(title: "Set the table", points: 5, category: "Kitchen"),
        ChoreTemplate(title: "Finish your homework", points: 15, category: "School"),
        ChoreTemplate(title: "Feed the pet", points: 5, category: "Pets")
    ]

    private static let builtInRewards: [RewardTemplate] = [
        RewardTemplate(title: "Extra 30 minutes of screen time", cost: 30),
        RewardTemplate(title: "Pick the movie for movie night", cost: 40)
    ]
}
