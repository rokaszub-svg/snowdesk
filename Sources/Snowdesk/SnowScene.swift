import AppKit
import SpriteKit

final class Flake {
    let node: SKSpriteNode
    var fall: CGFloat = 60
    var phase: CGFloat = 0
    var wobbleFreq: CGFloat = 1
    var wobbleAmp: CGFloat = 10
    var depth: CGFloat = 1
    var size: CGFloat = 3
    var spin: CGFloat = 0
    var foreground = true
    var chunk = false
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    init(node: SKSpriteNode) { self.node = node }
}

final class Snowball {
    let node: SKSpriteNode
    var x: CGFloat
    var r: CGFloat
    var vx: CGFloat
    let targetR: CGFloat
    var rolling = true
    init(node: SKSpriteNode, x: CGFloat, r: CGFloat, vx: CGFloat, targetR: CGFloat) {
        self.node = node; self.x = x; self.r = r; self.vx = vx; self.targetR = targetR
    }
}

final class SnowScene: SKScene {
    /// This screen's frame in Cocoa global coordinates.
    let screenFrame: CGRect
    private let prefs = Prefs.shared

    private var flakes: [Flake] = []
    private var regularCount = 0
    private var piles: [CGWindowID: Pile] = [:]
    /// Visible window piles on this screen, front-to-back.
    private var order: [Pile] = []
    private var ground: Pile!
    private var balls: [Snowball] = []
    private var plow: SKNode?
    private var plowX: CGFloat = 0

    private var lastTime: TimeInterval = 0
    private var lastRebuild: TimeInterval = 0
    private var lastBallCheck: TimeInterval = 0
    private var lastSignature = 0

    init(size: CGSize, screenFrame: CGRect) {
        self.screenFrame = screenFrame
        super.init(size: size)
        backgroundColor = .clear
        anchorPoint = .zero
        scaleMode = .resizeFill
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) not used") }

    override func didMove(to view: SKView) {
        guard ground == nil else { return }
        ground = Pile(id: 0, frame: CGRect(x: 0, y: 0, width: size.width, height: 0), isGround: true)
        addChild(ground.node)
        for _ in 0..<targetCount() {
            let f = makeFlake()
            f.node.position = CGPoint(x: .random(in: 0...size.width), y: .random(in: 0...size.height))
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard let ground else { return }
        ground.frame = CGRect(x: 0, y: 0, width: size.width, height: 0)
        ground.resize(to: size.width)
    }

    // MARK: - Public actions

    func runSnowplow() {
        guard plow == nil else { return }
        let node = SKNode()
        let tractor = SKLabelNode(text: "🚜")
        tractor.fontSize = 46
        tractor.verticalAlignmentMode = .bottom
        tractor.horizontalAlignmentMode = .center
        node.addChild(tractor)
        let blade = SKShapeNode(rectOf: CGSize(width: 8, height: 28), cornerRadius: 2)
        blade.fillColor = NSColor(calibratedRed: 1.0, green: 0.76, blue: 0.1, alpha: 1)
        blade.strokeColor = NSColor.black.withAlphaComponent(0.35)
        blade.position = CGPoint(x: -30, y: 14)
        node.addChild(blade)
        node.zPosition = 8
        plowX = size.width + 60
        node.position = CGPoint(x: plowX, y: 2)
        addChild(node)
        plow = node
    }

    func clearSnowballs() {
        for b in balls {
            b.node.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
        }
        balls.removeAll()
    }

    func shakeOffAll() {
        for p in order { shake(p, fraction: 1) }
    }

    func clearAllSnow() {
        for p in piles.values { p.clear() }
        ground?.clear()
        clearSnowballs()
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        guard ground != nil else { return }
        let dt = CGFloat(lastTime == 0 ? 1.0 / 60 : min(currentTime - lastTime, 0.05))
        lastTime = currentTime

        syncWindows(currentTime)
        topUpFlakes()
        stepFlakes(dt)
        stepBalls(dt, currentTime)
        stepPlow(dt)

        if currentTime - lastRebuild > 1.0 / 15 {
            lastRebuild = currentTime
            for (k, p) in order.enumerated() where p.dirty {
                p.rebuild { x, y in self.isCovered(x, y, before: k) }
            }
            if ground.dirty { ground.rebuild { _, _ in false } }
        }
    }

    // MARK: - Windows

    private func syncWindows(_ now: TimeInterval) {
        var newOrder: [Pile] = []
        var seen = Set<CGWindowID>()
        var hasher = Hasher()

        for w in WindowTracker.shared.windows {
            let r = w.frame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
            guard r.maxY > 0, r.maxY <= size.height + 1, r.maxX > 0, r.minX < size.width else { continue }
            seen.insert(w.id)
            hasher.combine(w.id)
            hasher.combine(r.minX)
            hasher.combine(r.maxY)
            hasher.combine(r.width)

            if let p = piles[w.id] {
                if p.missingSince != nil {
                    p.missingSince = nil
                    p.node.isHidden = false
                }
                if p.frame != r {
                    let moved = abs(r.minX - p.frame.minX) + abs(r.maxY - p.frame.maxY)
                    if moved > 40 { shake(p, fraction: 0.6) } // fast drag knocks snow off
                    p.frame = r
                    p.resize(to: r.width)
                    p.dirty = true
                }
                newOrder.append(p)
            } else {
                let p = Pile(id: w.id, frame: r)
                piles[w.id] = p
                addChild(p.node)
                newOrder.append(p)
            }
        }

        // Windows that vanished (minimised, other Space, closed): keep snow for a while.
        for (id, p) in Array(piles) where !seen.contains(id) {
            if let since = p.missingSince {
                if now - since > 600 {
                    p.node.removeFromParent()
                    piles[id] = nil
                }
            } else {
                p.missingSince = now
                p.node.isHidden = true
            }
        }

        let sig = hasher.finalize()
        if sig != lastSignature {
            lastSignature = sig
            for p in newOrder { p.dirty = true }
        }
        order = newOrder
    }

    private func isCovered(_ x: CGFloat, _ y: CGFloat, before index: Int) -> Bool {
        var j = 0
        while j < index && j < order.count {
            if order[j].frame.contains(CGPoint(x: x, y: y)) { return true }
            j += 1
        }
        return false
    }

    private func shake(_ p: Pile, fraction: CGFloat) {
        var spawned = 0
        var i = 0
        while i < p.heights.count {
            let h = p.heights[i]
            if h > 0.8 {
                let take = h * fraction
                p.heights[i] -= take
                if i + 1 < p.heights.count { p.heights[i + 1] *= (1 - fraction) }
                if spawned < 70 && CGFloat.random(in: 0...5) < take {
                    let f = makeFlake(chunk: true)
                    f.node.position = CGPoint(x: p.frame.minX + CGFloat(i) * Pile.colW, y: p.top + h * 0.5)
                    f.vx = .random(in: -50...50)
                    f.vy = .random(in: 0...70)
                    spawned += 1
                }
            }
            i += 2
        }
        p.dirty = true
    }

    // MARK: - Flakes

    private func targetCount() -> Int {
        let area = (size.width * size.height) / (1440 * 900)
        return max(10, Int(CGFloat(prefs.intensity) * 500 * area))
    }

    @discardableResult
    private func makeFlake(chunk: Bool = false) -> Flake {
        let fg = chunk || Double.random(in: 0...1) < 0.7
        let star = fg && !chunk && Double.random(in: 0...1) < 0.06
        let node = SKSpriteNode(texture: star ? Textures.star : Textures.dot)
        let f = Flake(node: node)
        f.foreground = fg
        f.chunk = chunk

        let scale = CGFloat(prefs.flakeSize)
        if chunk { f.size = .random(in: 2...4) }
        else if star { f.size = .random(in: 9...15) * scale }
        else if fg { f.size = .random(in: 2.2...5.5) * scale }
        else { f.size = .random(in: 1.2...2.6) * scale }

        let d = f.size * (star ? 1.0 : 1.7)
        node.size = CGSize(width: d, height: d)
        node.alpha = fg ? .random(in: 0.8...1) : .random(in: 0.35...0.6)
        node.zPosition = fg ? 10 : 1
        f.depth = fg ? 1 : 0.5
        f.fall = (fg ? CGFloat.random(in: 45...85) : .random(in: 22...40)) * (star ? 0.7 : 1)
        f.wobbleFreq = .random(in: 0.6...1.8)
        f.wobbleAmp = .random(in: 6...22) * f.depth
        f.phase = .random(in: 0...(2 * .pi))
        f.spin = star ? .random(in: -1.2...1.2) : 0

        addChild(node)
        flakes.append(f)
        if !chunk { regularCount += 1 }
        return f
    }

    private func topUpFlakes() {
        let target = targetCount()
        guard regularCount < target else { return }
        for _ in 0..<min(12, target - regularCount) {
            let f = makeFlake()
            f.node.position = CGPoint(x: .random(in: 0...size.width), y: size.height + .random(in: 2...40))
        }
    }

    private func remove(at i: Int) {
        let f = flakes[i]
        f.node.removeFromParent()
        if !f.chunk { regularCount -= 1 }
        flakes.swapAt(i, flakes.count - 1)
        flakes.removeLast()
    }

    private func stepFlakes(_ dt: CGFloat) {
        let wind = CGFloat(prefs.wind) * 45
        let speed = CGFloat(prefs.speed)
        let accumulate = prefs.accumulate
        let maxH = CGFloat(prefs.maxPile)
        let target = targetCount()
        let w = size.width
        let h = size.height

        var i = 0
        while i < flakes.count {
            let f = flakes[i]
            let p = f.node.position
            var nx: CGFloat
            let ny: CGFloat

            if f.chunk {
                f.vy -= 420 * dt
                f.vx += (wind - f.vx) * 0.5 * dt
                nx = p.x + f.vx * dt
                ny = p.y + f.vy * dt
            } else {
                f.phase += f.wobbleFreq * dt
                nx = p.x + (wind * f.depth + sin(f.phase) * f.wobbleAmp) * dt * speed
                ny = p.y - f.fall * dt * speed
                if f.spin != 0 { f.node.zRotation += f.spin * dt }
            }

            var landed = false
            if f.foreground && accumulate && ny < p.y {
                landed = tryLand(x: nx, from: p.y, to: ny, size: f.size, maxH: maxH)
            }

            if landed || ny < -12 {
                if f.chunk || regularCount > target {
                    remove(at: i)
                    continue
                }
                f.node.position = CGPoint(x: .random(in: -20...(w + 20)), y: h + .random(in: 4...30))
                i += 1
                continue
            }

            if nx < -25 { nx += w + 50 } else if nx > w + 25 { nx -= w + 50 }
            f.node.position = CGPoint(x: nx, y: ny)
            i += 1
        }
    }

    private func tryLand(x: CGFloat, from y0: CGFloat, to y1: CGFloat, size s: CGFloat, maxH: CGFloat) -> Bool {
        let amount = s * 0.55
        for (k, p) in order.enumerated() {
            guard x >= p.frame.minX, x <= p.frame.maxX else { continue }
            let surface = p.top + p.height(at: x)
            if y0 >= surface && y1 < surface {
                if isCovered(x, surface, before: k) { continue }
                p.add(at: x, amount: amount, maxH: maxH)
                return true
            }
        }
        if y1 < ground.height(at: x) {
            ground.add(at: x, amount: amount * 0.6, maxH: maxH * 1.3)
            return true
        }
        return false
    }

    // MARK: - Snowballs

    private func stepBalls(_ dt: CGFloat, _ now: TimeInterval) {
        if prefs.snowballs && now - lastBallCheck > 1 {
            lastBallCheck = now
            let avg = ground.heights.reduce(0, +) / CGFloat(ground.heights.count)
            if balls.count < 6 && avg > CGFloat(prefs.maxPile) * 0.35 && Double.random(in: 0...1) < 0.12 {
                spawnBall()
            }
        }

        for b in balls where b.rolling {
            b.x += b.vx * dt
            b.node.zRotation -= b.vx * dt / max(b.r, 1)
            let i = ground.index(for: b.x)
            let lo = max(0, i - 2)
            let hi = min(ground.heights.count - 1, i + 2)
            var gathered: CGFloat = 0
            for j in lo...hi {
                let take = min(ground.heights[j], 6 * dt)
                ground.heights[j] -= take
                gathered += take
            }
            ground.dirty = true
            b.r = min(b.targetR, b.r + gathered * 0.6 + 0.6 * dt)
            if b.r >= b.targetR || b.x < b.r || b.x > size.width - b.r { b.rolling = false }
        }

        for b in balls {
            b.node.setScale((b.r * 2) / Textures.ballSize)
            b.node.position = CGPoint(x: b.x, y: ground.height(at: b.x) * 0.5 + b.r - 1)
        }
    }

    private func spawnBall() {
        guard size.width > 160 else { return }
        let node = SKSpriteNode(texture: Textures.ball)
        node.zPosition = 6
        let dir: CGFloat = prefs.wind > 0.05 ? 1 : prefs.wind < -0.05 ? -1 : (Bool.random() ? 1 : -1)
        let b = Snowball(node: node,
                         x: .random(in: 80...(size.width - 80)),
                         r: 4,
                         vx: dir * .random(in: 22...40),
                         targetR: .random(in: 11...20))
        node.setScale((b.r * 2) / Textures.ballSize)
        addChild(node)
        balls.append(b)
    }

    // MARK: - Snowplow

    private func stepPlow(_ dt: CGFloat) {
        guard let node = plow else { return }
        plowX -= 260 * dt
        let front = plowX - 34
        node.position = CGPoint(x: plowX, y: 2 + abs(sin(plowX * 0.08)) * 2)

        // Clear everything behind the blade, bank some of it in front.
        let iFront = ground.index(for: front)
        var pushed: CGFloat = 0
        if iFront < ground.heights.count {
            for j in iFront..<ground.heights.count where ground.heights[j] > 0 {
                pushed += ground.heights[j]
                ground.heights[j] = 0
            }
        }
        if pushed > 0 {
            for j in max(0, iFront - 6)..<iFront {
                ground.heights[j] = min(32, ground.heights[j] + pushed * 0.05)
            }
            for _ in 0..<min(6, Int(pushed / 3) + 1) {
                let f = makeFlake(chunk: true)
                f.node.position = CGPoint(x: front - 4, y: .random(in: 4...22))
                f.vx = -CGFloat.random(in: 60...170)
                f.vy = .random(in: 60...200)
            }
        }
        ground.dirty = true

        for b in balls where b.x + b.r > front && b.x - b.r < plowX + 30 {
            b.x = front - b.r
            b.rolling = false
        }

        if plowX < -90 {
            node.removeFromParent()
            plow = nil
            balls.removeAll { b in
                if b.x + b.r < 0 { b.node.removeFromParent(); return true }
                return false
            }
        }
    }
}
