// PG13iOSApp.swift — iOS only

import SwiftUI

@main
struct PG13iOSApp: App {
    init() { QM.registerFonts() }

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(AppState.shared)
        }
    }
}
