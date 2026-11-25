import AppKit
import SpriteKit

/// Character art lives in Contents/Resources/Sprites (PNG @2x).
enum Sprites {
    private static var cache: [String: SKTexture] = [:]

    static func texture(_ name: String) -> SKTexture {
        if let t = cache[name] { return t }
        let t: SKTexture
        if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Sprites"),
           let img = NSImage(contentsOf: url) {
            t = SKTexture(image: img)
        } else {
            t = SKTexture()
        }
        cache[name] = t
        return t
    }

    static func node(_ name: String, _ w: CGFloat, _ h: CGFloat) -> SKSpriteNode {
        let n = SKSpriteNode(texture: texture(name))
        n.size = CGSize(width: w, height: h)
        return n
    }
}
