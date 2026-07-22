import CoreGraphics
import Foundation

/// Wormhole tunnel — port of themes/horizon.js. A stream of stars rushes past
/// the camera down a corkscrewing tube of energy hoops, with a glow at the far
/// end. Three.js perspective is replaced with a hand-rolled projection matching
/// VortexTheme's approach.
final class WarpTheme: Theme {
    let id = "horizon"
    let name = "WARP"
    let palette = Palette(bg: "#12081f", accent: "#ff4fd8", dim: "#5a3a7a")

    private static let count = 1600
    private static let tunnelRadius: Double = 3
    private static let tunnelDepth: Double = 120
    private static let hoopCount = 10
    private static let camZ: Double = 8

    private var angle = [Double](repeating: 0, count: count)
    private var radius = [Double](repeating: 0, count: count)
    private var depth = [Double](repeating: 0, count: count)
    private var phase = [Double](repeating: 0, count: count)
    private var hoopZ = [Double](repeating: 0, count: hoopCount)

    private var frame = Frame()
    private var twist: Double = 0
    private var bassAvg: Float = 0
    private var flash: Double = 0
    private var dilate: Double = 1

    private let pink = RGB(0xff4fd8)
    private let cyan = RGB(0x40e0ff)
    private let gold = RGB(0xffd23e)

    init() {
        for i in 0..<Self.count {
            angle[i] = Double.random(in: 0...(2 * .pi))
            radius[i] = Self.tunnelRadius + Double.random(in: 0...2.2)
            depth[i] = 6 - Double.random(in: 0...Self.tunnelDepth)
            phase[i] = Double.random(in: 0...(2 * .pi))
        }
        for h in 0..<Self.hoopCount {
            hoopZ[h] = 6 - (Double(h) / Double(Self.hoopCount)) * Self.tunnelDepth
        }
    }

    func update(frame: Frame) {
        self.frame = frame
        let dt = frame.dt

        let speed = 8 + Double(frame.mid) * 70
        twist += (0.15 + Double(frame.mid) * 0.6) * dt

        bassAvg += (frame.bass - bassAvg) * Float(min(dt * 2, 1))
        if frame.bass > 0.3 && frame.bass > bassAvg * 1.4 { flash = 1 }
        flash = max(flash - dt * 2.2, 0)

        dilate = 1 + Double(frame.bass) * 0.35 + 0.03 * sin(frame.time * 0.7)

        for i in 0..<Self.count {
            depth[i] += speed * dt
            if depth[i] > 6 {
                depth[i] -= Self.tunnelDepth
                angle[i] = Double.random(in: 0...(2 * .pi))
            }
        }
        for h in 0..<Self.hoopCount {
            hoopZ[h] += speed * dt
            if hoopZ[h] > 8 { hoopZ[h] -= Self.tunnelDepth }
        }
    }

    func draw(in ctx: CGContext, size: CGSize) {
        ctx.setFillColor(RGB(0x12081f).cgColor())
        ctx.fill(CGRect(origin: .zero, size: size))

        let time = frame.time
        let w = size.width, h = size.height
        let cx = w / 2, cy = h / 2
        let f = h * 0.65
        let camX = sin(time * 0.3) * 0.8
        let camY = cos(time * 0.23) * 0.6
        let roll = 0.3 * sin(time * 0.12)
        let cosR = cos(roll), sinR = sin(roll)

        // Project a world point (camera looks down -Z from camZ) to the screen.
        func project(_ x: Double, _ y: Double, _ z: Double) -> (CGPoint, Double)? {
            let zCam = Self.camZ - z
            guard zCam > 0.5 else { return nil }
            let dx = x - camX, dy = y - camY
            let rx = dx * cosR - dy * sinR
            let ry = dx * sinR + dy * cosR
            let sx = cx + CGFloat(rx / zCam) * f
            let sy = cy - CGFloat(ry / zCam) * f
            return (CGPoint(x: sx, y: sy), zCam)
        }

        // Stars
        ctx.setBlendMode(.plusLighter)
        for i in 0..<Self.count {
            let a = angle[i] + twist * (0.4 + radius[i] * 0.1)
            let r = radius[i] * dilate
            guard let (p, zCam) = project(cos(a) * r, sin(a) * r, depth[i]) else { continue }

            let near = max(0, min((depth[i] + 60) / 66, 1))
            let spark = 0.5 + 0.5 * sin(time * 5 + phase[i])
            let trebleMix = spark * Double(frame.treble)
            let color = RGB(
                r: CGFloat(pink.r * near + cyan.r * (1 - near)) + CGFloat(gold.r) * CGFloat(trebleMix) * 0.5,
                g: CGFloat(pink.g * near + cyan.g * (1 - near)) + CGFloat(gold.g) * CGFloat(trebleMix) * 0.5,
                b: CGFloat(pink.b * near + cyan.b * (1 - near))
            )
            // Perspective size, capped so near stars streak past as bright
            // points instead of ballooning into screen-filling discs.
            let dot = min(max(CGFloat(0.06 / zCam) * f, 0.6), 4.5)
            ctx.setFillColor(color.cgColor(alpha: min(0.3 + CGFloat(near) * 0.7, 1)))
            ctx.fillEllipse(in: CGRect(x: p.x - dot / 2, y: p.y - dot / 2, width: dot, height: dot))
        }

        // Energy hoops
        let hoopAlpha = min(0.25 + flash * 0.6 + Double(frame.bass) * 0.2, 1)
        let hr = Self.tunnelRadius * dilate
        for h in 0..<Self.hoopCount {
            var started = false
            ctx.beginPath()
            for seg in 0...64 {
                let a = (Double(seg) / 64) * 2 * .pi + twist
                guard let (p, _) = project(cos(a) * hr, sin(a) * hr, hoopZ[h]) else { started = false; continue }
                if !started { ctx.move(to: p); started = true } else { ctx.addLine(to: p) }
            }
            ctx.setStrokeColor(pink.cgColor(alpha: CGFloat(hoopAlpha)))
            ctx.setLineWidth(2)
            ctx.strokePath()
        }

        // Distant glow at the mouth of the wormhole
        if let (gc, zCam) = project(0, 0, -90) {
            let gr = max(CGFloat(26 / zCam) * f, 8) * (1 + CGFloat(frame.bass) * 0.4)
            let a = min(0.6 + CGFloat(frame.level) * 0.4, 1)
            let colors = [pink.cgColor(alpha: a), pink.cgColor(alpha: 0)] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.drawRadialGradient(grad, startCenter: gc, startRadius: 0, endCenter: gc, endRadius: gr, options: [])
            }
        }
        ctx.setBlendMode(.normal)
    }
}
