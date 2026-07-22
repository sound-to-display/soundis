import CoreGraphics
import Foundation

/// Digital rain — port of themes/scope.js (RAIN). Columns of glyphs fall down a
/// CRT, each column tuned to its own frequency bin; bass leaves longer trails,
/// treble sparks the heads white-hot. Scanline + vignette overlay for the tube.
final class RainTheme: Theme {
    let id = "scope"
    let name = "RAIN"
    let palette = Palette(bg: "#050805", accent: "#4dff6a", dim: "#1d5a28")

    private static let colW: CGFloat = 16
    private static let glyphs = Array("アイウエオカキクケコサシスセソタチツテトナニヌネノ0123456789ABCDEF<>*+=")

    private var colY: [Double] = []
    private var colSpeed: [Double] = []
    private var colLen: [Double] = []
    private var frame = Frame()
    private let green = RGB(0x4dff6a)

    private func buildColumns(width: CGFloat, height: CGFloat) {
        let count = max(Int(ceil(width / Self.colW)), 1)
        colY = (0..<count).map { _ in Double.random(in: 0...Double(height)) }
        colSpeed = (0..<count).map { _ in 40 + Double.random(in: 0...80) }
        colLen = (0..<count).map { _ in 6 + Double.random(in: 0...14) }
    }

    // Stable glyph for a given column/cell so trails don't flicker as they fall.
    private func glyph(col: Int, cell: Int) -> Character {
        var n = (col &* 73856093) ^ (cell &* 19349663)
        n = (n >> 13) ^ n
        return Self.glyphs[abs(n) % Self.glyphs.count]
    }

    func update(frame: Frame) { self.frame = frame }

    func draw(in ctx: CGContext, size: CGSize) {
        let w = size.width, h = size.height
        let count = max(Int(ceil(w / Self.colW)), 1)
        if colY.count != count { buildColumns(width: w, height: h) }

        ctx.setFillColor(RGB(0x050805).cgColor())
        ctx.fill(CGRect(origin: .zero, size: size))

        let dt = frame.dt
        let fontSize = Self.colW - 2

        for i in 0..<count {
            let binIdx = min(Int((Double(i) / Double(count)) * 200), frame.bins.count - 1)
            let bin = Double(frame.bins[binIdx])
            let speed = colSpeed[i] * (0.35 + Double(frame.level) * 2.2 + bin * 1.5)
            colY[i] += speed * dt

            if colY[i] - colLen[i] * Double(Self.colW) > Double(h) {
                colY[i] = -Double.random(in: 0...Double(h) * 0.4)
                colSpeed[i] = 40 + Double.random(in: 0...80)
                colLen[i] = 6 + Double.random(in: 0...14)
            }

            let x = CGFloat(i) * Self.colW + Self.colW / 2
            let len = Int(colLen[i])
            let headCell = Int(floor(colY[i] / Double(Self.colW)))

            for k in 0...len {
                let cellY = CGFloat(colY[i]) - CGFloat(k) * Self.colW
                if cellY < -Self.colW || cellY > h + Self.colW { continue }

                if k == 0 {
                    // Bright head; treble adds a white-hot flicker.
                    let hot = min(0.55 + bin + Double(frame.treble) * 0.6, 1)
                    let g = glyph(col: i, cell: headCell + Int.random(in: 0...2))
                    let color = RGB(
                        r: (140 + CGFloat(hot) * 115) / 255,
                        g: 1,
                        b: (140 + CGFloat(hot) * 80) / 255
                    )
                    drawText(String(g), x: x, y: cellY, size: fontSize, color: color, alpha: CGFloat(hot),
                             align: .center, glow: (green, 4 + CGFloat(frame.treble) * 12 + CGFloat(bin) * 8))
                } else {
                    let fade = (1 - Double(k) / Double(len)) * (0.35 + bin * 0.5)
                    drawText(String(glyph(col: i, cell: headCell - k)), x: x, y: cellY,
                             size: fontSize, color: green, alpha: CGFloat(max(fade, 0.05)), align: .center)
                }
            }
        }

        // Bass beat: a horizontal pressure wave sweeps the wall of code.
        if frame.bass > 0.45 {
            let bandY = CGFloat(frame.time * 240).truncatingRemainder(dividingBy: h)
            ctx.setFillColor(green.cgColor(alpha: CGFloat(frame.bass) * 0.1))
            ctx.fill(CGRect(x: 0, y: bandY, width: w, height: 34))
        }

        drawCRT(in: ctx, size: size)
    }

    /// Scanlines + vignette — the phosphor tube overlay.
    private func drawCRT(in ctx: CGContext, size: CGSize) {
        let w = size.width, h = size.height
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.22))
        var y: CGFloat = 0
        while y < h {
            ctx.fill(CGRect(x: 0, y: y, width: w, height: 1))
            y += 3
        }
        let center = CGPoint(x: w / 2, y: h / 2)
        let colors = [
            CGColor(red: 0, green: 0, blue: 0, alpha: 0),
            CGColor(red: 0, green: 0, blue: 0, alpha: 0.55),
        ] as CFArray
        if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.55, 1]) {
            ctx.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: max(w, h) * 0.7, options: [])
        }
    }
}
