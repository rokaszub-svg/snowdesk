import AppKit
import SpriteKit

/// A strip of accumulated snow sitting on the top edge of a window (or the ground).
final class Pile {
    static let colW: CGFloat = 4

    let id: CGWindowID
    let isGround: Bool
    /// Window rect in scene coordinates. Snow sits on `frame.maxY`.
    var frame: CGRect
    var heights: [CGFloat]
    let node = SKShapeNode()
    var dirty = true
    var missingSince: TimeInterval?

    init(id: CGWindowID, frame: CGRect, isGround: Bool = false) {
        self.id = id
        self.frame = frame
        self.isGround = isGround
        heights = Array(repeating: 0, count: Pile.columns(for: frame.width))
        node.fillColor = NSColor(calibratedRed: 0.975, green: 0.985, blue: 1.0, alpha: 0.97)
        node.strokeColor = .clear
        node.lineWidth = 0
        node.isAntialiased = true
        node.zPosition = 5
    }

    static func columns(for width: CGFloat) -> Int { max(2, Int(ceil(width / colW)) + 1) }

    var top: CGFloat { frame.maxY }

    func index(for x: CGFloat) -> Int {
        let i = Int(((x - frame.minX) / Pile.colW).rounded())
        return min(heights.count - 1, max(0, i))
    }

    func height(at x: CGFloat) -> CGFloat { heights[index(for: x)] }

    func resize(to width: CGFloat) {
        let n = Pile.columns(for: width)
        guard n != heights.count else { return }
        let old = heights
        heights = (0..<n).map { i in
            let t = CGFloat(i) / CGFloat(max(1, n - 1))
            return old[min(old.count - 1, Int(t * CGFloat(old.count - 1)))]
        }
        dirty = true
    }

    /// Windows get rounded ends; the ground is flat-capped.
    private func limit(_ i: Int, _ maxH: CGFloat) -> CGFloat {
        if isGround { return maxH }
        let edge = CGFloat(min(i, heights.count - 1 - i))
        return min(maxH, 1.0 + edge * 0.9)
    }

    func add(at x: CGFloat, amount: CGFloat, maxH: CGFloat) {
        let i = index(for: x)
        deposit(i, amount * 0.5, maxH)
        deposit(i - 1, amount * 0.25, maxH)
        deposit(i + 1, amount * 0.25, maxH)
        relax(around: i, maxH)
        dirty = true
    }

    private func deposit(_ i: Int, _ a: CGFloat, _ maxH: CGFloat) {
        guard i >= 0, i < heights.count else { return }
        heights[i] = min(limit(i, maxH), heights[i] + a)
    }

    /// Lets steep spots slump into neighbours so piles look soft.
    private func relax(around c: Int, _ maxH: CGFloat) {
        let lo = max(0, c - 8)
        let hi = min(heights.count - 2, c + 8)
        guard lo <= hi else { return }
        for _ in 0..<2 {
            for i in lo...hi {
                let d = heights[i] - heights[i + 1]
                guard abs(d) > 1.2 else { continue }
                let t = (abs(d) - 1.2) * 0.5
                if d > 0 {
                    heights[i] -= t
                    heights[i + 1] = min(limit(i + 1, maxH), heights[i + 1] + t)
                } else {
                    heights[i + 1] -= t
                    heights[i] = min(limit(i, maxH), heights[i] + t)
                }
            }
        }
    }

    /// Removes snow around x (cursor swipe). Returns (x, removed) samples for spray.
    func knock(at x: CGFloat, radius: CGFloat) -> [(CGFloat, CGFloat)] {
        var out: [(CGFloat, CGFloat)] = []
        let lo = index(for: x - radius), hi = index(for: x + radius)
        guard lo <= hi else { return out }
        for i in lo...hi where heights[i] > 0.5 {
            out.append((frame.minX + CGFloat(i) * Pile.colW, heights[i]))
            heights[i] *= 0.15
        }
        if !out.isEmpty { dirty = true }
        return out
    }

    var total: CGFloat { heights.reduce(0, +) }

    func clear() {
        for i in heights.indices { heights[i] = 0 }
        dirty = true
    }

    func rebuild(isCovered: (CGFloat, CGFloat) -> Bool) {
        dirty = false
        var hasSnow = false
        let base = top - 1
        let path = CGMutablePath()
        path.move(to: CGPoint(x: frame.minX, y: base))
        for i in heights.indices {
            let x = min(frame.maxX, frame.minX + CGFloat(i) * Pile.colW)
            var h = heights[i]
            if h > 0.3 && isCovered(x, top + 1) { h = 0 }
            if h > 0.3 { hasSnow = true }
            path.addLine(to: CGPoint(x: x, y: base + max(0, h)))
        }
        path.addLine(to: CGPoint(x: frame.maxX, y: base))
        path.closeSubpath()
        node.path = hasSnow ? path : nil
    }
}
