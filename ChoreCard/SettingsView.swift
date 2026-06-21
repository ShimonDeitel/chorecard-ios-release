import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @AppStorage("chorecard.theme") private var themeRaw = AppTheme.system.rawValue

    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var restoreMessage: String?
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Chore Card \(v)"
    }

    var body: some View {
        NavigationStack {
            Form {
                proSection
                kidsSection
                appearanceSection
                summarySection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.ccAccent)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showShare) { ShareSheet(items: shareItems) }
            .alert("Erase All Data?", isPresented: $showDeleteConfirm) {
                Button("Erase", role: .destructive) {
                    appModel.deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently erases all kids, chores and points on this device. This can't be undone.")
            }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if store.isPro {
                HStack {
                    Label("Chore Card Pro", systemImage: "sparkles")
                    Spacer()
                    Text("Unlocked").foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Haptics.tap(); showPaywall = true
                } label: {
                    HStack {
                        Label("Unlock Pro", systemImage: "sparkles")
                        Spacer()
                        Text(store.displayPrice).foregroundStyle(.secondary)
                    }
                }
                Button("Restore Purchase") {
                    Task {
                        await store.restore()
                        restoreMessage = store.isPro ? "Restored." : "No previous purchase found."
                    }
                }
                if let restoreMessage {
                    Text(restoreMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        } footer: {
            if !store.isPro {
                Text("One-time purchase. Unlimited chores, multiple kids, custom rewards, PDF summary & sharing.")
            }
        }
    }

    private var kidsSection: some View {
        Section("Kids") {
            ForEach(appModel.kids()) { kid in
                HStack {
                    KidAvatar(name: kid.name, size: 28)
                    Text(kid.name)
                    Spacer()
                    Text("\(appModel.balance(for: kid)) pts").foregroundStyle(.secondary)
                }
            }
            .onDelete { idx in
                let kids = appModel.kids()
                idx.forEach { appModel.deleteKid(kids[$0]) }
            }
            if appModel.kids().isEmpty {
                Text("Add kids on the Home tab.").foregroundStyle(.secondary)
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $themeRaw) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var summarySection: some View {
        Section {
            Button {
                Haptics.tap()
                if store.isPro { shareSummary() } else { showPaywall = true }
            } label: {
                HStack {
                    Label("Share weekly summary", systemImage: "square.and.arrow.up")
                    Spacer()
                    if !store.isPro {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        } footer: {
            Text("Export a printable PDF and text recap of this week's leaderboard.")
        }
    }

    private var aboutSection: some View {
        Section {
            Button("Erase All Data", role: .destructive) { showDeleteConfirm = true }
            Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/chorecard-site/privacy.html")!)
        } footer: {
            Text(version).frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
        }
    }

    private func shareSummary() {
        let rows = appModel.leaderboard()
        var items: [Any] = [Summary.text(rows: rows)]
        if let pdf = Summary.pdf(rows: rows) { items.append(pdf) }
        shareItems = items
        showShare = true
    }
}
