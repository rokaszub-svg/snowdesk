import AppKit
import SpriteKit

/// Transparent, click-through window covering one display.
final class OverlayWindow: NSWindow {
    let skView: SKView
    let snowScene: SnowScene

    init(screen: NSScreen) {
        let frame = screen.frame
        skView = SKView(frame: NSRect(origin: .zero, size: frame.size))
        snowScene = SnowScene(size: frame.size, screenFrame: frame)

        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(frame, display: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        level = .statusBar // above the Dock and menu bar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        skView.allowsTransparency = true
        skView.preferredFramesPerSecond = 60
        skView.ignoresSiblingOrder = true
        skView.autoresizingMask = [.width, .height]
        contentView = skView
        skView.presentScene(snowScene)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
