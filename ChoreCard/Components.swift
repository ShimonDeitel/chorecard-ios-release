import SwiftUI

/// A round, monogram-style avatar for a kid (initials only — no PII, no photos).
struct KidAvatar: View {
    let name: String
    var size: CGFloat = 44
    var rank: Int? = nil

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        let s = String(letters).uppercased()
        return s.isEmpty ? "?" : s
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.ccAccent.opacity(0.14))
            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ccAccent)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if let rank, rank <= 3 {
                Image(systemName: "rosette")
                    .font(.system(size: size * 0.3, weight: .bold))
                    .foregroundStyle(rankColor(rank))
                    .offset(x: 4, y: -4)
            }
        }
    }

    private func rankColor(_ r: Int) -> Color {
        switch r {
        case 1: return Color(hex: "#D4AF37")   // gold
        case 2: return Color(hex: "#9AA0A6")   // silver
        default: return Color(hex: "#B07A45")  // bronze
        }
    }
}

/// A small labelled metric tile (reused on Home / Rewards).
struct MetricTile: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ccAccent)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.ccCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// A points badge — a flat capsule showing "+N" or "N pts".
struct PointsBadge: View {
    let points: Int
    var prefix: String = ""
    var body: some View {
        Text("\(prefix)\(points)")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Color.ccAccent)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.ccAccent.opacity(0.12), in: Capsule())
            .accessibilityLabel("\(points) points")
    }
}

/// A category chip used to filter the chore template library.
struct CategoryChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(selected ? Color.ccAccent : Color.ccCard, in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

/// Wraps UIActivityViewController so we can share a text/PDF summary.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

/// A simple empty-state placeholder used across screens.
struct EmptyHint: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}
