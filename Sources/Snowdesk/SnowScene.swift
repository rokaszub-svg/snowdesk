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

final class Gift {
    let node: SKSpriteNode
    var vx: CGFloat
    var vy: CGFloat = 0
    weak var restingOn: Pile?
    var onGround = false
    init(node: SKSpriteNode, vx: CGFloat) { self.node = node; self.vx = vx }
}

final class Snowman {
    let node: SKSpriteNode
    var x: CGFloat
    init(node: SKSpriteNode, x: CGFloat) { self.node = node; self.x = x }
}

final class Truck {
    let node = SKNode()
    var wheels: [SKSpriteNode] = []
    let beacon: SKSpriteNode
    var x: CGFloat
    init(x: CGFloat) {
        self.x = x
        beacon = Sprites.node("beacon", 46, 46)
        let body = Sprites.node("truck", 170, 85)
        body.zPosition = 1
        node.addChild(body)
        for wx in [50, 115, 150] as [CGFloat] {
            let w = Sprites.node("wheel", 22, 22)
            w.position = CGPoint(x: wx - 85, y: -24.5)
            w.zPosition = 2
            node.addChild(w)
            wheels.append(w)
        }
        beacon.position = CGPoint(x: -25, y: 37)
        beacon.zPosition = 3
        beacon.blendMode = .add
        node.addChild(beacon)
        beacon.run(.repeatForever(.sequence([
            .fadeAlpha(to: 1, duration: 0.12), .wait(forDuration: 0.12),
            .fadeAlpha(to: 0.1, duration: 0.18), .wait(forDuration: 0.2),
        ])))
    }
    /// Blade's leading edge, relative to node.x.
    static let front: CGFloat = -84
}

final class SledKid {
    let node = Sprites.node("kid", 100, 70)
    var x: CGFloat
    var speed: CGFloat
    init(x: CGFloat, speed: CGFloat) { self.x = x; self.speed = speed }
}

final class Sleigh {
    let node = Sprites.node("santa0", 320, 115)
    var x: CGFloat
    let baseY: CGFloat
    var t: CGFloat = 0
    var frameT: CGFloat = 0
    var frame = 0
    var drops: [CGFloat]
    let trail: SKEmitterNode
    init(x: CGFloat, baseY: CGFloat, drops: [CGFloat], trail: SKEmitterNode) {
        self.x = x; self.baseY = baseY; self.drops = drops; self.trail = trail
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
    private var gifts: [Gift] = []
    private var snowmen: [Snowman] = []
    private var truck: Truck?
    private var kid: SledKid?
    private var sleigh: Sleigh?

    private var lastTime: TimeInterval = 0
    private var lastRebuild: TimeInterval = 0
    private var lastBallCheck: TimeInterval = 0
    private var nextEvent: TimeInterval = 0
    private var firstEvent = false
    private var lastSignature = 0
    private var clock: CGFloat = 0

    private var blizzardUntil: CGFloat = 0
    private var lastMouse: CGPoint?

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
        guard truck == nil, ground != nil else { return }
        let t = Truck(x: size.width + 110)
        t.node.zPosition = 8
        t.node.position = CGPoint(x: t.x, y: 37)
        addChild(t.node)
        truck = t
    }

    func callSanta() {
        guard sleigh == nil, ground != nil else { return }
        let trail = SKEmitterNode()
        trail.particleTexture = Textures.dot
        trail.particleBirthRate = 90
        trail.particleLifetime = 1.6
        trail.particleLifetimeRange = 0.6
        trail.particleSpeed = 25
        trail.particleSpeedRange = 20
        trail.emissionAngle = .pi
        trail.emissionAngleRange = 0.8
        trail.yAcceleration = -30
        trail.particleSize = CGSize(width: 7, height: 7)
        trail.particleScaleRange = 0.6
        trail.particleScaleSpeed = -0.4
        trail.particleAlphaSpeed = -0.6
        trail.particleColor = NSColor(calibratedRed: 1, green: 0.85, blue: 0.4, alpha: 1)
        trail.particleColorBlendFactor = 1
        trail.particleBlendMode = .add
        trail.targetNode = self
        trail.zPosition = 11

        let drops = (0..<Int.random(in: 2...4)).map { _ in CGFloat.random(in: 0.15...0.85) * size.width }.sorted()
        let s = Sleigh(x: -180, baseY: size.height * .random(in: 0.62...0.8), drops: drops, trail: trail)
        s.node.zPosition = 12
        addChild(trail)
        addChild(s.node)
        sleigh = s
    }

    func sledRide() {
        guard kid == nil, ground != nil else { return }
        let k = SledKid(x: -60, speed: .random(in: 170...230))
        k.node.zPosition = 9
        addChild(k.node)
        kid = k
    }

    func buildSnowman(at x: CGFloat? = nil) {
        guard ground != nil, snowmen.count < 4 else { return }
        let sx = x ?? .random(in: 90...max(91, size.width - 90))
        let node = Sprites.node("snowman", 65, 100)
        node.zPosition = 7
        node.setScale(0.01)
        let s = Snowman(node: node, x: sx)
        addChild(node)
        snowmen.append(s)
        positionSnowman(s)
        node.run(.sequence([.scale(to: 1.15, duration: 0.25), .scale(to: 1.0, duration: 0.12)]))
        burst(at: CGPoint(x: sx, y: 20), count: 25, up: 160)
    }

    func blizzard() {
        blizzardUntil = clock + 25
    }

    func clearSnowballs() {
        for b in balls { b.node.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()])) }
        balls.removeAll()
    }

    func shakeOffAll() {
        for p in order { shake(p, fraction: 1) }
    }

    func clearAllSnow() {
        for p in piles.values { p.clear() }
        ground?.clear()
        clearSnowballs()
        for s in snowmen { s.node.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()])) }
        snowmen.removeAll()
        for g in gifts { g.node.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()])) }
        gifts.removeAll()
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        guard ground != nil else { return }
        let dt = CGFloat(lastTime == 0 ? 1.0 / 30 : min(currentTime - lastTime, 0.066))
        lastTime = currentTime
        clock += dt

        syncWindows(currentTime)
        topUpFlakes()
        stepFlakes(dt)
        stepCursor(dt)
        stepBalls(dt, currentTime)
        stepGifts(dt)
        stepTruck(dt)
        stepKid(dt)
        stepSleigh(dt)
        scheduleEvents(currentTime)

        if currentTime - lastRebuild > 0.2 {
            lastRebuild = currentTime
            for (k, p) in order.enumerated() where p.dirty {
                p.rebuild { x, y in self.isCovered(x, y, before: k) }
            }
            if ground.dirty { ground.rebuild { _, _ in false } }
        }
    }

    private var blizzardLevel: CGFloat {
        let left = blizzardUntil - clock
        guard left > 0 else { return 0 }
        return min(1, left / 3, (25 - left) / 3)
    }

    private var wind: CGFloat {
        let gust = sin(clock * 0.13) * 0.25 + sin(clock * 0.41) * 0.1
        return (CGFloat(prefs.wind) + gust + blizzardLevel * 1.6 * sin(clock * 0.3 + 1)) * 45
    }

    // MARK: - Events

    private func scheduleEvents(_ now: TimeInterval) {
        if nextEvent == 0 {
            nextEvent = now + 6
            firstEvent = true
        }
        let avg = ground.total / CGFloat(ground.heights.count)
        if prefs.characters && truck == nil && avg > CGFloat(prefs.maxPile) * 0.75 { runSnowplow() }

        guard now >= nextEvent else { return }
        nextEvent = now + .random(in: 45...110)
        guard prefs.characters else { return }
        if firstEvent { firstEvent = false; callSanta(); return }
        let r = Double.random(in: 0...1)
        if r < 0.4 { callSanta() }
        else if r < 0.7 { sledRide() }
        else if r < 0.85 { blizzard() }
        else { buildSnowman() }
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
                    if moved > 40 { shake(p, fraction: 0.6) }
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
                if spawned < 60 && CGFloat.random(in: 0...5) < take {
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

    private func burst(at p: CGPoint, count: Int, up: CGFloat) {
        for _ in 0..<count {
            let f = makeFlake(chunk: true)
            f.node.position = CGPoint(x: p.x + .random(in: -12...12), y: p.y + .random(in: 0...20))
            f.vx = .random(in: -140...140)
            f.vy = .random(in: up * 0.3...up)
        }
    }

    // MARK: - Cursor

    private func stepCursor(_ dt: CGFloat) {
        guard prefs.cursor else { lastMouse = nil; return }
        let g = NSEvent.mouseLocation
        let m = CGPoint(x: g.x - screenFrame.minX, y: g.y - screenFrame.minY)
        defer { lastMouse = m }
        guard m.x >= -50, m.x <= size.width + 50, m.y >= -50, m.y <= size.height + 50 else { return }

        // Flakes swerve around the pointer.
        let R: CGFloat = 70
        for f in flakes where !f.chunk {
            let dx = f.node.position.x - m.x
            let dy = f.node.position.y - m.y
            guard abs(dx) < R, abs(dy) < R else { continue }
            let d2 = dx * dx + dy * dy
            guard d2 < R * R, d2 > 1 else { continue }
            let d = sqrt(d2)
            let push = (R - d) / R * 260 * dt
            f.node.position = CGPoint(x: f.node.position.x + dx / d * push, y: f.node.position.y + dy / d * push * 0.6)
        }

        // A fast swipe through a pile knocks the snow off.
        guard let last = lastMouse else { return }
        let speed = hypot(m.x - last.x, m.y - last.y) / max(dt, 0.001)
        guard speed > 700 else { return }
        for p in order + [ground!] {
            guard m.x >= p.frame.minX, m.x <= p.frame.maxX else { continue }
            let surface = p.top + p.height(at: m.x)
            guard m.y >= p.top - 6, m.y <= surface + 10 else { continue }
            let removed = p.knock(at: m.x, radius: 26)
            let dir: CGFloat = m.x >= last.x ? 1 : -1
            for (x, h) in removed where CGFloat.random(in: 0...4) < h {
                let f = makeFlake(chunk: true)
                f.node.position = CGPoint(x: x, y: p.top + h * 0.5)
                f.vx = dir * .random(in: 60...220)
                f.vy = .random(in: 60...220)
            }
            break
        }
    }

    // MARK: - Flakes

    private func targetCount() -> Int {
        let area = (size.width * size.height) / (1440 * 900)
        let mult = 1 + blizzardLevel * 1.8
        return max(10, Int(CGFloat(prefs.intensity) * 380 * area * mult))
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
        let wind = self.wind
        let speed = CGFloat(prefs.speed) * (1 + blizzardLevel * 0.6)
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

    /// Finds the first surface a falling point crosses. Returns the pile it hit.
    private func surfaceHit(x: CGFloat, from y0: CGFloat, to y1: CGFloat) -> Pile? {
        for (k, p) in order.enumerated() {
            guard x >= p.frame.minX, x <= p.frame.maxX else { continue }
            let surface = p.top + p.height(at: x)
            if y0 >= surface && y1 < surface && !isCovered(x, surface, before: k) { return p }
        }
        if y1 < ground.height(at: x) { return ground }
        return nil
    }

    private func tryLand(x: CGFloat, from y0: CGFloat, to y1: CGFloat, size s: CGFloat, maxH: CGFloat) -> Bool {
        guard let p = surfaceHit(x: x, from: y0, to: y1) else { return false }
        if p === ground {
            ground.add(at: x, amount: s * 0.9, maxH: maxH * 1.3)
        } else {
            p.add(at: x, amount: s * 1.3, maxH: maxH)
        }
        return true
    }

    // MARK: - Snowballs & snowmen

    private func stepBalls(_ dt: CGFloat, _ now: TimeInterval) {
        if prefs.snowballs && now - lastBallCheck > 1 {
            lastBallCheck = now
            let avg = ground.total / CGFloat(ground.heights.count)
            if balls.count < 6 && avg > CGFloat(prefs.maxPile) * 0.3 && Double.random(in: 0...1) < 0.15 {
                spawnBall()
            }
            // Three resting snowballs become a snowman.
            let resting = balls.filter { !$0.rolling }
            if prefs.characters && resting.count >= 3 && snowmen.count < 4 {
                let use = Array(resting.prefix(3))
                let x = use.map { $0.x }.reduce(0, +) / 3
                for b in use {
                    b.node.run(.sequence([.group([.move(to: CGPoint(x: x, y: b.node.position.y + 20), duration: 0.35),
                                                  .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
                }
                balls.removeAll { b in use.contains { $0 === b } }
                run(.wait(forDuration: 0.3)) { [weak self] in self?.buildSnowman(at: x) }
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
        for s in snowmen { positionSnowman(s) }
    }

    private func positionSnowman(_ s: Snowman) {
        s.node.position = CGPoint(x: s.x, y: ground.height(at: s.x) * 0.5 + 49)
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

    private func smash(_ s: Snowman) {
        burst(at: CGPoint(x: s.x, y: 30), count: 50, up: 260)
        s.node.removeFromParent()
        snowmen.removeAll { $0 === s }
    }

    // MARK: - Gifts

    private func dropGift(at x: CGFloat, y: CGFloat, vx: CGFloat) {
        let g = Gift(node: Sprites.node("gift", 18, 18), vx: vx)
        g.node.position = CGPoint(x: x, y: y)
        g.node.zPosition = 9
        addChild(g.node)
        gifts.append(g)
        if gifts.count > 10 {
            let old = gifts.removeFirst()
            old.node.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
        }
    }

    private func stepGifts(_ dt: CGFloat) {
        for g in gifts {
            if g.onGround {
                g.node.position = CGPoint(x: g.node.position.x, y: ground.height(at: g.node.position.x) * 0.6 + 8)
                continue
            }
            if let p = g.restingOn {
                let x = g.node.position.x
                let still = !p.node.isHidden && order.contains { $0 === p } && x >= p.frame.minX && x <= p.frame.maxX
                if still {
                    g.node.position = CGPoint(x: x, y: p.top + p.height(at: x) * 0.6 + 8)
                    continue
                }
                g.restingOn = nil
            }
            g.vy -= 500 * dt
            g.vx *= (1 - 0.5 * dt)
            let p0 = g.node.position
            let nx = p0.x + g.vx * dt
            let ny = p0.y + g.vy * dt
            g.node.zRotation += g.vx * dt * 0.02
            if let hit = surfaceHit(x: nx, from: p0.y - 8, to: ny - 8) {
                g.vy = 0
                g.node.zRotation = .random(in: -0.15...0.15)
                if hit === ground { g.onGround = true } else { g.restingOn = hit }
                burst(at: CGPoint(x: nx, y: ny - 6), count: 6, up: 90)
                g.node.position = CGPoint(x: nx, y: ny)
            } else {
                g.node.position = CGPoint(x: nx, y: ny)
            }
        }
    }

    // MARK: - Snowplow truck

    private func stepTruck(_ dt: CGFloat) {
        guard let t = truck else { return }
        let v: CGFloat = 200
        t.x -= v * dt
        let front = t.x + Truck.front
        t.node.position = CGPoint(x: t.x, y: 37 + abs(sin(t.x * 0.05)) * 1.2)
        for w in t.wheels { w.zRotation += v * dt / 11 }

        let iFront = ground.index(for: front)
        var pushed: CGFloat = 0
        if iFront < ground.heights.count {
            for j in iFront..<ground.heights.count where ground.heights[j] > 0 {
                pushed += ground.heights[j]
                ground.heights[j] = 0
            }
        }
        if pushed > 0 {
            for j in max(0, iFront - 5)..<iFront {
                ground.heights[j] = min(30, ground.heights[j] + pushed * 0.04)
            }
            for _ in 0..<min(8, Int(pushed / 3) + 1) {
                let f = makeFlake(chunk: true)
                f.node.position = CGPoint(x: front - 2, y: .random(in: 6...50))
                f.vx = -CGFloat.random(in: 80...240)
                f.vy = .random(in: 80...260)
            }
        }
        ground.dirty = true

        for b in balls where b.x + b.r > front && b.x - b.r < t.x + 85 {
            b.x = front - b.r
            b.rolling = false
        }
        for g in gifts where g.onGround && g.node.position.x > front && g.node.position.x < t.x + 85 {
            g.node.position.x = front - 9
        }
        for s in snowmen where s.x > front && s.x < t.x { smash(s) }

        if t.x < -110 {
            t.node.removeFromParent()
            truck = nil
            balls.removeAll { b in
                if b.x + b.r < 0 { b.node.removeFromParent(); return true }
                return false
            }
            gifts.removeAll { g in
                if g.onGround && g.node.position.x < 0 { g.node.removeFromParent(); return true }
                return false
            }
        }
    }

    // MARK: - Sledding kid

    private func stepKid(_ dt: CGFloat) {
        guard let k = kid else { return }
        k.x += k.speed * dt
        let gh = ground.height(at: k.x)
        k.node.position = CGPoint(x: k.x, y: gh * 0.7 + 30 + abs(sin(k.x * 0.06)) * 2)
        k.node.zRotation = sin(k.x * 0.03) * 0.04

        // Carve a track and kick up powder.
        let i = ground.index(for: k.x - 20)
        for j in max(0, i - 6)...min(ground.heights.count - 1, i + 6) { ground.heights[j] *= 0.92 }
        ground.dirty = true
        if gh > 2 && Double.random(in: 0...1) < 0.6 {
            let f = makeFlake(chunk: true)
            f.node.position = CGPoint(x: k.x - 45, y: gh * 0.7 + 6)
            f.vx = -CGFloat.random(in: 40...140)
            f.vy = .random(in: 60...180)
        }
        for s in snowmen where abs(s.x - (k.x + 40)) < 12 { smash(s) }

        if k.x > size.width + 70 {
            k.node.removeFromParent()
            kid = nil
        }
    }

    // MARK: - Santa

    private func stepSleigh(_ dt: CGFloat) {
        guard let s = sleigh else { return }
        s.x += 240 * dt
        s.t += dt
        s.frameT += dt
        if s.frameT > 0.16 {
            s.frameT = 0
            s.frame = 1 - s.frame
            s.node.texture = Sprites.texture("santa\(s.frame)")
        }
        let y = s.baseY + sin(s.t * 1.6) * 26
        s.node.position = CGPoint(x: s.x, y: y)
        s.node.zRotation = cos(s.t * 1.6) * 0.06
        s.trail.position = CGPoint(x: s.x - 150, y: y - 30)

        if let next = s.drops.first, s.x - 90 >= next {
            s.drops.removeFirst()
            dropGift(at: s.x - 110, y: y, vx: 120)
        }

        if s.x > size.width + 200 {
            s.node.removeFromParent()
            s.trail.particleBirthRate = 0
            s.trail.run(.sequence([.wait(forDuration: 2.5), .removeFromParent()]))
            sleigh = nil
        }
    }
}
