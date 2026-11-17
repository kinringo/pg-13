// PG13App.swift: macOS only (AppDelegate + ContentView)

import SwiftUI
import AppKit

// MARK: - macOS ContentView

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        AppShell()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var panel: NSPanel?
    private var themeObserver: Any?

    /// The Figma desktop frame size. Longer screens scroll inside it.
    /// The Workstation frames are 500 x 1000. Clamped so the panel still fits
    /// under the menu bar on a short display.
    static var compactSize: NSSize {
        let available = NSScreen.main?.visibleFrame.height ?? 1000
        return NSSize(width: 500, height: min(1000, available - 24))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        QM.registerFonts()
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
            contentRect: NSRect(origin: .zero, size: Self.compactSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        // The content view runs under the title bar, so size the whole frame,
        // not the content rect, or the title bar adds 32pt on top.
        panel.setContentSize(Self.compactSize)
        panel.setFrame(NSRect(origin: .zero, size: Self.compactSize), display: false)
        // The heading band and footer are intrinsically sized, so without a cap
        // the panel grows to whatever the content asks for.
        panel.contentMaxSize = Self.compactSize
        panel.maxSize = Self.compactSize
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
            panel.setFrameOrigin(NSPoint(x: screenFrame.maxX - Self.compactSize.width - 16,
                                         y: screenFrame.minY + 16))
        }

        let appState = AppState.shared
        applyTheme(isLight: appState.lightMode, to: panel)

        let contentView = ContentView().environmentObject(appState)
        let host = NSHostingView(rootView: contentView)
        // Without this the hosting view pushes its intrinsic height onto the
        // panel, and the heading band plus footer make that the whole screen.
        if #available(macOS 13.0, *) { host.sizingOptions = [] }
        panel.contentView = host
        panel.setContentSize(Self.compactSize)

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
        panel.backgroundColor = QM.nsBgBase(isLight: isLight)
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
            panel.setFrame(NSRect(x: screen.visibleFrame.maxX - Self.compactSize.width - 16,
                                  y: screen.visibleFrame.minY + 16,
                                  width: Self.compactSize.width, height: Self.compactSize.height),
                           display: true, animate: true)
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
