import SwiftUI

/// The parent approval queue. Each pending completion can be approved (locks in the points)
/// or rejected (discarded). Swipe right to approve, left to reject — or use the buttons.
struct ApproveView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        NavigationStack {
            ZStack {
                CCBackground()
                content
                    .id(appModel.lastChangeToken)
            }
            .navigationTitle("Approve")
        }
    }

    @ViewBuilder
    private var content: some View {
        let pending = appModel.pendingCompletions()
        if pending.isEmpty {
            EmptyHint(symbol: "checkmark.circle",
                      title: "All caught up",
                      message: "When a kid marks a chore done, it shows up here for you to approve.")
        } else {
            List {
                ForEach(pending) { completion in
                    ApproveRow(completion: completion)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading) {
                            Button {
                                Haptics.success(); appModel.approve(completion)
                            } label: { Label("Approve", systemImage: "checkmark") }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Haptics.warning(); appModel.reject(completion)
                            } label: { Label("Reject", systemImage: "xmark") }
                        }
                }
            }
            .listStyle(.plain)
        }
    }
}

struct ApproveRow: View {
    @EnvironmentObject var appModel: AppModel
    let completion: Completion

    private var kidName: String { completion.kid?.name ?? "Someone" }

    var body: some View {
        HStack(spacing: 12) {
            KidAvatar(name: kidName, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(completion.choreTitle).font(.body.weight(.semibold))
                Text("\(kidName) · \(completion.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            PointsBadge(points: completion.pointsAwarded, prefix: "+")
            Button {
                Haptics.success(); appModel.approve(completion)
            } label: {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.ccAccent, in: Circle())
            }
            .accessibilityIdentifier("approve-\(completion.id)")
            .accessibilityLabel("Approve")
        }
        .padding(12)
        .background(Color.ccCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
