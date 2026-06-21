import SwiftUI

/// Tab shell. The four primary screens live here; "Assign chore" is presented modally from Home.
struct HomeView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            ApproveView()
                .tabItem { Label("Approve", systemImage: "checkmark.circle.fill") }
                .badge(appModel.pendingCompletions().count)

            RewardsView()
                .tabItem { Label("Rewards", systemImage: "gift.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Color.ccAccent)
    }
}
