import Foundation
import UIKit

/// Builds the shareable weekly summary (PRO). Produces both plain text (for the share sheet)
/// and a one-page PDF written to a temp file.
enum Summary {

    /// A plain-text weekly recap, suitable for Messages / Notes / email.
    static func text(rows: [LeaderboardRow], now: Date = .now) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        var lines = ["Chore Card — week of \(df.string(from: Scoring.startOfWeek(now)))", ""]
        if rows.isEmpty {
            lines.append("No kids added yet.")
        } else {
            for row in rows {
                lines.append("\(row.rank). \(row.name) — \(row.weeklyPoints) pts this week (\(row.totalPoints) total)")
            }
        }
        lines.append("")
        lines.append("Made with Chore Card.")
        return lines.joined(separator: "\n")
    }

    /// Renders a single-page A4-ish PDF and returns the file URL (or nil on failure).
    static func pdf(rows: [LeaderboardRow], now: Date = .now) -> URL? {
        let pageWidth: CGFloat = 612    // 8.5in @ 72dpi
        let pageHeight: CGFloat = 792   // 11in
        let bounds = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChoreCard-Summary.pdf")

        let df = DateFormatter(); df.dateStyle = .medium

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                let margin: CGFloat = 48
                var y: CGFloat = margin

                let title = "Chore Card"
                title.draw(at: CGPoint(x: margin, y: y),
                           withAttributes: [.font: UIFont.boldSystemFont(ofSize: 30)])
                y += 42

                let subtitle = "Week of \(df.string(from: Scoring.startOfWeek(now)))"
                subtitle.draw(at: CGPoint(x: margin, y: y),
                              withAttributes: [.font: UIFont.systemFont(ofSize: 16),
                                               .foregroundColor: UIColor.darkGray])
                y += 40

                if rows.isEmpty {
                    "No kids added yet.".draw(at: CGPoint(x: margin, y: y),
                                              withAttributes: [.font: UIFont.systemFont(ofSize: 16)])
                } else {
                    for row in rows {
                        let line = "\(row.rank).  \(row.name)"
                        line.draw(at: CGPoint(x: margin, y: y),
                                  withAttributes: [.font: UIFont.systemFont(ofSize: 18, weight: .semibold)])
                        let pts = "\(row.weeklyPoints) pts this week  ·  \(row.totalPoints) total"
                        let size = (pts as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 15)])
                        pts.draw(at: CGPoint(x: pageWidth - margin - size.width, y: y + 2),
                                 withAttributes: [.font: UIFont.systemFont(ofSize: 15),
                                                  .foregroundColor: UIColor.darkGray])
                        y += 34
                        if y > pageHeight - margin { break }
                    }
                }

                let footer = "Made with Chore Card."
                footer.draw(at: CGPoint(x: margin, y: pageHeight - margin),
                            withAttributes: [.font: UIFont.systemFont(ofSize: 12),
                                             .foregroundColor: UIColor.lightGray])
            }
            return url
        } catch {
            return nil
        }
    }
}
