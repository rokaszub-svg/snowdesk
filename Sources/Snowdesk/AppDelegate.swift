import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private enum State { case running, paused, stopped }

    private var statusItem: NSStatusItem!
    private var overlays: [OverlayWindow] = []
    private var trackTimer: Timer?
    private var settingsWindow: NSWindow?
    private var hideWork: DispatchWorkItem?
    private var bag = Set<AnyCancellable>()
    private var state: State = .running

    private var scenes: [SnowScene] { overlays.map { $0.snowScene } }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let img = NSImage(systemSymbolName: "snowflake", accessibilityDescription: AppInfo.name)
            img?.isTemplate = true
            button.image = img
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        WindowTracker.shared.refresh()
        let timer = Timer(timeInterval: 0.1, repeats: true) { _ in WindowTracker.shared.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        trackTimer = timer

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        Prefs.shared.$allScreens
            .dropFirst()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.rebuildOverlays() } }
            .store(in: &bag)

        rebuildOverlays()
    }

    // MARK: - Overlays

    @objc private func screensChanged() { rebuildOverlays() }

    private func rebuildOverlays() {
        overlays.forEach { $0.orderOut(nil); $0.close() }
        overlays.removeAll()
        guard state != .stopped else { return }
        let screens = Prefs.shared.allScreens ? NSScreen.screens : Array(NSScreen.screens.prefix(1))
        for screen in screens {
            let w = OverlayWindow(screen: screen)
            w.orderFrontRegardless()
            overlays.append(w)
        }
        applyPause()
    }

    private func applyPause() {
        for o in overlays { o.skView.isPaused = (state == .paused) }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status: String
        switch state {
        case .running: status = "Running"
        case .paused: status = "Paused"
        case .stopped: status = "Stopped"
        }
        let header = NSMenuItem(title: "\(AppInfo.name) — \(status)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        switch state {
        case .running:
            add(menu, "Pause", #selector(pause))
            add(menu, "Stop", #selector(stop))
        case .paused:
            add(menu, "Resume", #selector(resume))
            add(menu, "Stop", #selector(stop))
        case .stopped:
            add(menu, "Let It Snow", #selector(start))
        }
        menu.addItem(.separator())

        let live = state == .running
        add(menu, "Run Snowplow", #selector(snowplow), enabled: live, symbol: "truck.box")
        add(menu, "Shake Snow Off Windows", #selector(shakeOff), enabled: live, symbol: "wind")
        add(menu, "Clear Snowballs", #selector(clearSnowballs), enabled: state != .stopped, symbol: "circle.circle")
        add(menu, "Clear All Snow", #selector(clearAll), enabled: state != .stopped, symbol: "trash")
        menu.addItem(.separator())

        add(menu, "Settings…", #selector(openSettings), key: ",")
        add(menu, "Hide Snow for Screenshot (10 s)", #selector(hideForScreenshot), enabled: state != .stopped)
        menu.addItem(.separator())
        add(menu, "Quit \(AppInfo.name)", #selector(quit), key: "q")
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector,
                     key: String = "", enabled: Bool = true, symbol: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: enabled ? action : nil, keyEquivalent: key)
        item.target = self
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        menu.addItem(item)
        return item
    }

    // MARK: - Actions

    @objc private func pause() { state = .paused; applyPause() }
    @objc private func resume() { state = .running; applyPause() }
    @objc private func stop() { state = .stopped; rebuildOverlays() }
    @objc private func start() { state = .running; rebuildOverlays() }

    @objc private func snowplow() { scenes.forEach { $0.runSnowplow() } }
    @objc private func shakeOff() { scenes.forEach { $0.shakeOffAll() } }
    @objc private func clearSnowballs() { scenes.forEach { $0.clearSnowballs() } }
    @objc private func clearAll() { scenes.forEach { $0.clearAllSnow() } }

    @objc private func hideForScreenshot() {
        overlays.forEach { $0.orderOut(nil) }
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state != .stopped else { return }
            self.overlays.forEach { $0.orderFrontRegardless() }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView())
            let w = NSWindow(contentViewController: host)
            w.title = "\(AppInfo.name) Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
