import AppKit
import SpriteKit

enum Textures {
    static let ballSize: CGFloat = 64

    /// Soft round flake.
    static let dot: SKTexture = SKTexture(image: image(32) { ctx, s in
        let c = CGPoint(x: s / 2, y: s / 2)
        let colors = [
            NSColor.white.cgColor,
            NSColor.white.withAlphaComponent(0.9).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor,
        ] as CFArray
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.4, 1])!
        ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0, endCenter: c, endRadius: s / 2, options: [])
    })

    /// Six-armed crystal flake.
    static let star: SKTexture = SKTexture(image: image(64) { ctx, s in
        let c = s / 2
        let r = s * 0.42
        ctx.setShadow(offset: .zero, blur: s * 0.08, color: NSColor.white.withAlphaComponent(0.9).cgColor)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(s * 0.065)
        ctx.setLineCap(.round)
        for k in 0..<6 {
            let a = CGFloat(k) * .pi / 3
            ctx.move(to: CGPoint(x: c, y: c))
            ctx.addLine(to: CGPoint(x: c + cos(a) * r, y: c + sin(a) * r))
            for t in [0.5, 0.75] as [CGFloat] {
                let bx = c + cos(a) * r * t
                let by = c + sin(a) * r * t
                let len = r * (t == 0.5 ? 0.3 : 0.2)
                for sgn in [-1.0, 1.0] as [CGFloat] {
                    let b = a + sgn * .pi / 4
                    ctx.move(to: CGPoint(x: bx, y: by))
                    ctx.addLine(to: CGPoint(x: bx + cos(b) * len, y: by + sin(b) * len))
                }
            }
        }
        ctx.strokePath()
    })

    /// Shaded snowball with a few marks so rolling is visible.
    static let ball: SKTexture = SKTexture(image: image(ballSize) { ctx, s in
        let rect = CGRect(x: 1, y: 1, width: s - 2, height: s - 2)
        ctx.saveGState()
        ctx.addEllipse(in: rect)
        ctx.clip()
        let colors = [
            NSColor.white.cgColor,
            NSColor(calibratedRed: 0.93, green: 0.96, blue: 1.0, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.74, green: 0.82, blue: 0.93, alpha: 1).cgColor,
        ] as CFArray
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1])!
        ctx.drawRadialGradient(grad,
                               startCenter: CGPoint(x: s * 0.38, y: s * 0.64), startRadius: 0,
                               endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: s * 0.55,
                               options: [.drawsAfterEndLocation])
        ctx.setFillColor(NSColor(calibratedRed: 0.78, green: 0.85, blue: 0.94, alpha: 0.9).cgColor)
        let marks: [(CGFloat, CGFloat, CGFloat)] = [(0.30, 0.30, 0.07), (0.62, 0.42, 0.05), (0.48, 0.72, 0.06), (0.72, 0.70, 0.04), (0.22, 0.58, 0.045)]
        for (x, y, r) in marks {
            ctx.fillEllipse(in: CGRect(x: s * x - s * r, y: s * y - s * r, width: s * r * 2, height: s * r * 2))
        }
        ctx.restoreGState()
    })

    private static func image(_ side: CGFloat, draw: @escaping (CGContext, CGFloat) -> Void) -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            if let ctx = NSGraphicsContext.current?.cgContext { draw(ctx, side) }
            return true
        }
    }
}
