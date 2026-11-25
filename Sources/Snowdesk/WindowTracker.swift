import AppKit
import CoreGraphics

struct TrackedWindow {
    let id: CGWindowID
    /// Cocoa global coordinates (origin bottom-left of the primary screen).
    let frame: CGRect
}

/// Polls the on-screen window list. Window bounds are readable without
/// Screen Recording permission (only titles are restricted), so no prompt is needed.
final class WindowTracker {
    static let shared = WindowTracker()

    /// Normal app windows, front-to-back.
    private(set) var windows: [TrackedWindow] = []
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    func refresh() {
        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var result: [TrackedWindow] = []
        result.reserveCapacity(info.count)

        for w in info {
            guard
                let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                let pid = w[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
                let num = w[kCGWindowNumber as String] as? UInt32,
                let boundsDict = w[kCGWindowBounds as String] as? NSDictionary,
                let b = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }

            let alpha = (w[kCGWindowAlpha as String] as? Double) ?? 1
            if alpha < 0.1 || b.width < 120 || b.height < 60 { continue }

            let cocoa = CGRect(x: b.minX, y: primaryHeight - b.maxY, width: b.width, height: b.height)
            result.append(TrackedWindow(id: CGWindowID(num), frame: cocoa))
        }
        windows = result
    }
}
