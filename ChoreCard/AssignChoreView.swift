import SwiftUI

/// Assign a chore: pick from the 30+ template library (filterable by category), tweak the
/// points, or write a custom one. Respects the free weekly chore limit.
struct AssignChoreView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: String? = nil
    @State private var showPaywall = false

    // Custom chore
    @State private var customTitle = ""
    @State private var customPoints = 10

    private var filtered: [ChoreTemplate] {
        guard let cat = selectedCategory else { return ChoreLibrary.templates }
        return ChoreLibrary.templates.filter { $0.category == cat }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                CCBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if !store.isPro {
                            limitNote
                        }
                        categoryRow
                        templateList
                        customSection
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Assign a chore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var limitNote: some View {
        let remaining = max(0, AppModel.freeWeeklyChoreLimit - appModel.choresThisWeek())
        return HStack(spacing: 10) {
            Image(systemName: "info.circle")
            Text(remaining > 0
                 ? "\(remaining) free chore\(remaining == 1 ? "" : "s") left this week."
                 : "You've used your 3 free chores this week. Unlock Pro for unlimited.")
                .font(.footnote)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .ccCard()
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(title: "All", selected: selectedCategory == nil) {
                    Haptics.tap(); selectedCategory = nil
                }
                ForEach(ChoreLibrary.categories, id: \.self) { cat in
                    CategoryChip(title: cat, selected: selectedCategory == cat) {
                        Haptics.tap(); selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var templateList: some View {
        VStack(spacing: 10) {
            ForEach(filtered) { template in
                Button {
                    assign(template)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.title).font(.body.weight(.medium))
                            Text(template.category).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        PointsBadge(points: template.points, prefix: "+")
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.ccAccent)
                    }
                    .padding(12)
                    .background(Color.ccCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Or write your own").font(.headline)
            VStack(spacing: 14) {
                TextField("Chore title", text: $customTitle)
                    .textInputAutocapitalization(.sentences)
                    .padding(12)
                    .background(Color.ccField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("custom-chore-title")

                Stepper(value: $customPoints, in: 1...100, step: 5) {
                    HStack {
                        Text("Points")
                        Spacer()
                        PointsBadge(points: customPoints, prefix: "+")
                    }
                }

                Button {
                    assignCustom()
                } label: {
                    Text("Add chore").frame(maxWidth: .infinity).padding(.vertical, 2)
                }
                .prominentButton()
                .disabled(customTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .ccCard()
        }
        .padding(.top, 6)
    }

    private func assign(_ template: ChoreTemplate) {
        guard appModel.canAddChore() else { showPaywall = true; return }
        if appModel.addChore(from: template) != nil { Haptics.success(); dismiss() }
        else { showPaywall = true }
    }

    private func assignCustom() {
        guard appModel.canAddChore() else { showPaywall = true; return }
        if appModel.addChore(title: customTitle, points: customPoints, category: "Custom") != nil {
            Haptics.success(); dismiss()
        } else { showPaywall = true }
    }
}
