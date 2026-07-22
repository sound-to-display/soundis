import CoreGraphics
import Foundation

/// 8-bit spectrum fleet — port of themes/arcade.js (INVADERS). Each frequency
/// band is a column of pixel aliens; louder bands stack higher. A ship chases
/// the loudest column and fires on the bass beat, spraying explosion sparks.
final class InvadersTheme: Theme {
    let id = "arcade"
    let name = "INVADERS"
    let palette = Palette(bg: "#10122b", accent: "#ffd23e", dim: "#4a4e8a")

    private static let barCount = 16
    private static let rows = 6
    private static let starCount = 50
    private static let sparkPool = 50

    private static let invaderA = [
        "..X.....X..", "...X...X...", "..XXXXXXX..", ".XX.XXX.XX.",
        "XXXXXXXXXXX", "X.XXXXXXX.X", "X.X.....X.X", "...XX.XX...",
    ]
    private static let invaderB = [
        "..X.....X..", "X..X...X..X", "X.XXXXXXX.X", "XXX.XXX.XXX",
        "XXXXXXXXXXX", ".XXXXXXXXX.", "..X.....X..", ".X.......X.",
    ]
    private let rowColors = [
        RGB(0x3ec54b), RGB(0xa7d32c), RGB(0xffd23e), RGB(0xff9130), RGB(0xff4b4b), RGB(0xff4fd8),
    ]

    private var targets = [Double](repeating: 0, count: barCount)
    private var displayed = [Double](repeating: 0, count: barCount)
    private var stars = [Double](repeating: 0, count: starCount * 3)
    private var sparks = [Double](repeating: 0, count: sparkPool * 5)
    private var sparkCursor = 0
    private var shipX: Double = 0.5
    private var laserLife: Double = 0
    private var laserCol = 0
    private var bassAvg: Float = 0
    private var frame = Frame()

    private let ship = RGB(0xffd23e)
    private let scoreColor = RGB(0x4a4e8a)

    init() {
        for i in 0..<Self.starCount {
            stars[i * 3] = Double.random(in: 0...1)
            stars[i * 3 + 1] = Double.random(in: 0...1)
            stars[i * 3 + 2] = Double(1 + Int.random(in: 0...2))
        }
    }

    func update(frame: Frame) { self.frame = frame }

    private func binsToBars() {
        let bins = frame.bins
        let usable = Double(bins.count) * 0.75
        let groupSize = usable / Double(Self.barCount)
        for bar in 0..<Self.barCount {
            let start = Int(Double(bar) * groupSize)
            let end = Int(Double(bar + 1) * groupSize)
            guard end > start else { targets[bar] = 0; continue }
            var sum: Double = 0
            for i in start..<end { sum += Double(bins[i]) }
            targets[bar] = sum / Double(end - start)
        }
    }

    private func spawnSparks(x: Double, y: Double, count: Int) {
        for _ in 0..<count {
            let o = sparkCursor * 5
            sparks[o] = x
            sparks[o + 1] = y
            sparks[o + 2] = Double.random(in: -0.5...0.5) * 220
            sparks[o + 3] = Double.random(in: -0.7...0.3) * 220
            sparks[o + 4] = 1
            sparkCursor = (sparkCursor + 1) % Self.sparkPool
        }
    }

    private func drawInvader(_ ctx: CGContext, _ pattern: [String], x: CGFloat, y: CGFloat, px: CGFloat, color: RGB) {
        ctx.setFillColor(color.cgColor())
        for (r, row) in pattern.enumerated() {
            for (c, ch) in row.enumerated() where ch == "X" {
                ctx.fill(CGRect(x: x + CGFloat(c) * px, y: y + CGFloat(r) * px, width: px, height: px))
            }
        }
    }

    func draw(in ctx: CGContext, size: CGSize) {
        let w = size.width, h = size.height
        let dt = frame.dt, time = frame.time

        binsToBars()
        for i in 0..<Self.barCount {
            let idle = 0.06 + 0.04 * sin(time * 2 + Double(i) * 0.7)
            targets[i] = min(max(targets[i] * 1.6, idle), 1)
            if targets[i] > displayed[i] { displayed[i] = targets[i] }
            else { displayed[i] = max(displayed[i] - dt * 1.4, targets[i]) }
        }

        ctx.setFillColor(RGB(0x10122b).cgColor())
        ctx.fill(CGRect(origin: .zero, size: size))

        // Starfield
        let starSpeed = 0.02 + Double(frame.level) * 0.25
        for i in 0..<Self.starCount {
            let layer = stars[i * 3 + 2]
            stars[i * 3 + 1] += starSpeed * layer * dt
            if stars[i * 3 + 1] > 1 { stars[i * 3 + 1] -= 1; stars[i * 3] = Double.random(in: 0...1) }
            ctx.setFillColor(CGColor(red: 180.0 / 255, green: 190.0 / 255, blue: 1, alpha: 0.2 + 0.15 * CGFloat(layer)))
            ctx.fill(CGRect(x: CGFloat(stars[i * 3]) * w, y: CGFloat(stars[i * 3 + 1]) * h,
                            width: CGFloat(layer), height: CGFloat(layer)))
        }

        // Invader fleet
        let fieldW = min(w * 0.88, 980)
        let colW = fieldW / CGFloat(Self.barCount)
        let px = max((colW / 15).rounded(.down), 1)
        let invW = 11 * px
        let invH = 8 * px
        let rowGap = invH + px * 4
        let startX = (w - fieldW) / 2
        let fleetBase = h * 0.68
        let marchX = CGFloat(sin(time * 0.9)) * colW * 0.25
        let animFrame = Int(floor(time * 2 + Double(frame.level) * 6)) % 2
        let pattern = animFrame == 0 ? Self.invaderA : Self.invaderB

        var strongest = 0
        for col in 0..<Self.barCount {
            if displayed[col] > displayed[strongest] { strongest = col }
            let lit = Int((displayed[col] * Double(Self.rows)).rounded())
            let bob = CGFloat(sin(time * 3 + Double(col))) * px * CGFloat(frame.bass) * 4
            if lit == 0 { continue }
            for row in 0..<lit {
                let x = startX + CGFloat(col) * colW + (colW - invW) / 2 + marchX
                let y = fleetBase - CGFloat(row) * rowGap + bob
                drawInvader(ctx, pattern, x: x, y: y, px: px, color: rowColors[min(row, rowColors.count - 1)])
            }
        }

        // Ship chases the loudest column
        let targetX = Double((startX + (CGFloat(strongest) + 0.5) * colW) / w)
        shipX += (targetX - shipX) * min(dt * 4, 1)
        let shipPx = max(px, 2)
        let shipY = h * 0.86
        let sx = CGFloat(shipX) * w
        ctx.setFillColor(ship.cgColor())
        ctx.fill(CGRect(x: sx - shipPx * 4, y: shipY, width: shipPx * 8, height: shipPx * 2))
        ctx.fill(CGRect(x: sx - shipPx, y: shipY - shipPx * 2, width: shipPx * 2, height: shipPx * 2))

        // Fire on the bass beat
        bassAvg += (frame.bass - bassAvg) * Float(min(dt * 2, 1))
        if frame.bass > 0.3 && frame.bass > bassAvg * 1.4 && laserLife <= 0 {
            laserLife = 1
            laserCol = strongest
            let hitY = fleetBase - CGFloat((displayed[strongest] * Double(Self.rows)).rounded()) * rowGap + invH
            spawnSparks(x: Double(startX + (CGFloat(strongest) + 0.5) * colW), y: Double(hitY), count: 8)
        }
        if laserLife > 0 {
            laserLife = max(laserLife - dt * 5, 0)
            let lx = startX + (CGFloat(laserCol) + 0.5) * colW
            ctx.setFillColor(ship.cgColor(alpha: CGFloat(laserLife)))
            ctx.fill(CGRect(x: lx - shipPx / 2, y: h * 0.2, width: shipPx, height: shipY - h * 0.2))
        }

        // Explosion sparks
        for s in 0..<Self.sparkPool {
            let o = s * 5
            if sparks[o + 4] <= 0 { continue }
            sparks[o + 4] -= dt * 1.6
            sparks[o + 3] += 300 * dt
            sparks[o] += sparks[o + 2] * dt
            sparks[o + 1] += sparks[o + 3] * dt
            ctx.setFillColor(ship.cgColor(alpha: CGFloat(max(sparks[o + 4], 0))))
            ctx.fill(CGRect(x: CGFloat(sparks[o]), y: CGFloat(sparks[o + 1]), width: 3, height: 3))
        }

        // Arcade score
        let score = String(format: "%05d", Int((Double(frame.level) * 99990).rounded()))
        drawText("SCORE \(score)", x: startX, y: h * 0.1, size: 12, color: scoreColor)
    }
}
