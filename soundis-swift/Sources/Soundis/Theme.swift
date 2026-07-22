import CoreGraphics
import AppKit

/// Theme interface mirroring the Electron app:
/// { id, name, palette, update(frame), draw(ctx, size) }.
/// All themes draw with Core Graphics into the stage's backing layer.
protocol Theme: AnyObject {
    var id: String { get }
    var name: String { get }
    var palette: Palette { get }
    func update(frame: Frame)
    func draw(in ctx: CGContext, size: CGSize)
    func dispose()
}

extension Theme {
    func dispose() {}
}

enum ThemeRegistry {
    /// Selector order locked to match the Electron app: 1-5 keys.
    static func makeThemes() -> [Theme] {
        [
            VortexTheme(),
            WarpTheme(),
            SeismoTheme(),
            RainTheme(),
            InvadersTheme(),
        ]
    }
}

// MARK: - Color helpers

extension NSColor {
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: String(hex.dropFirst())).scanHexInt64(&value)
        self.init(
            red: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }
}

struct RGB {
    var r: CGFloat
    var g: CGFloat
    var b: CGFloat

    init(_ hex: UInt32) {
        r = CGFloat((hex >> 16) & 0xff) / 255
        g = CGFloat((hex >> 8) & 0xff) / 255
        b = CGFloat(hex & 0xff) / 255
    }

    init(r: CGFloat, g: CGFloat, b: CGFloat) {
        self.r = r
        self.g = g
        self.b = b
    }

    func lerp(_ other: RGB, _ t: CGFloat) -> RGB {
        let k = min(max(t, 0), 1)
        return RGB(r: r + (other.r - r) * k, g: g + (other.g - g) * k, b: b + (other.b - b) * k)
    }

    func cgColor(alpha: CGFloat = 1) -> CGColor {
        CGColor(red: min(r, 1), green: min(g, 1), blue: min(b, 1), alpha: alpha)
    }
}
