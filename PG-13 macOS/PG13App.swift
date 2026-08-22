// PromptGenerator.swift — macOS only (AppDelegate + ContentView)

import SwiftUI
import AppKit

// MARK: - macOS ContentView

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {

            // Compact header — PG-13 · tabs · theme toggle in one bar
            HStack(spacing: 0) {
                Text("PG·13")
                    .font(QM.mono(10))
                    .foregroundColor(QM.accentMagenta)
                    .tracking(2)

                Rectangle().fill(QM.border).frame(width: 1, height: 10)
                    .padding(.horizontal, 10)

                ForEach(Array(["Generate", "History", "Folders"].enumerated()), id: \.offset) { idx, name in
                    Button(action: { appState.activeTab = idx }) {
                        VStack(spacing: 0) {
                            Text(name.uppercased())
                                .font(QM.mono(9))
                                .foregroundColor(appState.activeTab == idx ? QM.accentCyan : QM.textMuted)
                                .tracking(1.5)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                            Rectangle()
                                .fill(appState.activeTab == idx ? QM.accentCyan : Color.clear)
                                .frame(height: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: { appState.lightMode.toggle() }) {
                    Image(systemName: appState.lightMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 10))
                        .foregroundColor(QM.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 22)
            .background(QM.bgElevated)
            .overlay(alignment: .bottom) {
                Rectangle().fill(QM.border).frame(height: 1)
            }

            // Tab content
            ZStack {
                QM.bgBase.ignoresSafeArea()
                Group {
                    if appState.activeTab == 0 {
                        GenerateView(vm: appState.generateVM)
                    } else if appState.activeTab == 1 {
                        HistoryView()
                    } else {
                        FoldersView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Footer
            Rectangle().fill(QM.border).frame(height: 1)
            HStack {
                Circle().fill(QM.accentCyan).frame(width: 5, height: 5)
                Text("Claude · Sonnet 5")
                    .font(QM.mono(9))
                    .foregroundColor(QM.textMuted)
                Spacer()
                Text("PG·13")
                    .font(QM.mono(9))
                    .foregroundColor(QM.textMuted)
                    .tracking(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(QM.bgElevated)
        }
        .background(QM.bgBase)
        .frame(minWidth: 380, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .preferredColorScheme(appState.lightMode ? .light : .dark)
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var panel: NSPanel?
    private var themeObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            if let img = NSImage(named: "AppIcon") {
                img.size = NSSize(width: 18, height: 18)
                img.isTemplate = true
                button.image = img
            } else {
                button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "PG-13")
            }
            button.action = #selector(togglePanel)
            button.target = self
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 680),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        panel.level = .normal
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        // Green = toggle compact ↔ expanded
        if let green = panel.standardWindowButton(.zoomButton) {
            green.action = #selector(zoomPanel)
            green.target = self
        }

        if let screenFrame = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: screenFrame.maxX - 420 - 16, y: screenFrame.minY + 16))
        }

        let appState = AppState.shared
        applyTheme(isLight: appState.lightMode, to: panel)

        let contentView = ContentView().environmentObject(appState)
        panel.contentView = NSHostingView(rootView: contentView)

        self.panel = panel
        panel.orderFront(nil)

        themeObserver = NotificationCenter.default.addObserver(
            forName: .pg13ThemeChanged,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self, let panel = self.panel else { return }
            let isLight = notif.object as? Bool ?? false
            self.applyTheme(isLight: isLight, to: panel)
        }
    }

    private func applyTheme(isLight: Bool, to panel: NSPanel) {
        panel.appearance = NSAppearance(named: isLight ? .aqua : .darkAqua)
        panel.backgroundColor = isLight
            ? NSColor(Color(hex: "FBF0E8"))
            : NSColor(Color(hex: "0D0D0D"))
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil); return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        panel?.orderFront(nil); return true
    }

    private var isZoomed = false
    @objc func zoomPanel() {
        guard let panel = panel, let screen = NSScreen.main else { return }
        if isZoomed {
            panel.setFrame(NSRect(x: screen.visibleFrame.maxX - 420 - 16,
                                  y: screen.visibleFrame.minY + 16,
                                  width: 420, height: 680), display: true, animate: true)
            isZoomed = false
        } else {
            let w: CGFloat = 560
            let h = min(screen.visibleFrame.height - 32, 880)
            panel.setFrame(NSRect(x: screen.visibleFrame.maxX - w - 16,
                                  y: screen.visibleFrame.minY + 16,
                                  width: w, height: h), display: true, animate: true)
            isZoomed = true
        }
    }

    @objc func togglePanel() {
        guard let panel = panel else { return }
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFront(nil) }
    }
}

// MARK: - App Entry Point

@main
struct PromptGeneratorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene { Settings { EmptyView() } }
}
