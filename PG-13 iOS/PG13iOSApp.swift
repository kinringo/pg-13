// PG13iOSApp.swift — iOS only

import SwiftUI

@main
struct PG13iOSApp: App {
    var body: some Scene {
        WindowGroup {
            iOSContentView()
                .environmentObject(AppState.shared)
        }
    }
}

// MARK: - iOS ContentView

struct iOSContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.activeTab) {

            NavigationStack {
                GenerateView(vm: appState.generateVM)
                    .navigationTitle("PG·13")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(QM.bgElevated, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { appState.lightMode.toggle() }) {
                                Image(systemName: appState.lightMode ? "moon.fill" : "sun.max.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(QM.textMuted)
                            }
                        }
                    }
            }
            .tabItem { Label("Generate", systemImage: "sparkles") }
            .tag(0)

            NavigationStack {
                DocsView(vm: appState.docVM)
                    .navigationTitle("Docs")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(QM.bgElevated, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem { Label("Docs", systemImage: "doc.text") }
            .tag(1)

            NavigationStack {
                HistoryView()
                    .navigationTitle("History")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(QM.bgElevated, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem { Label("History", systemImage: "clock") }
            .tag(2)

            NavigationStack {
                FoldersView()
                    .navigationTitle("Folders")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(QM.bgElevated, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem { Label("Folders", systemImage: "folder") }
            .tag(3)
        }
        .tint(QM.accentCyan)
        .preferredColorScheme(appState.lightMode ? .light : .dark)
        .onAppear { applyTabBarAppearance() }
        .onChangeCompat(of: appState.lightMode) { _ in applyTabBarAppearance() }
    }

    private func applyTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = QM.uiBgElevated
        // Update global proxy
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        // Force existing tab bar instances to pick up the new appearance immediately
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.rootViewController?.findTabBarController()?.tabBar.standardAppearance = appearance
                window.rootViewController?.findTabBarController()?.tabBar.scrollEdgeAppearance = appearance
            }
        }
    }
}

private extension UIViewController {
    func findTabBarController() -> UITabBarController? {
        if let tbc = self as? UITabBarController { return tbc }
        for child in children {
            if let found = child.findTabBarController() { return found }
        }
        return nil
    }
}
