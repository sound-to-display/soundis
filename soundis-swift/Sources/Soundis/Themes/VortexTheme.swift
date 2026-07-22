import CoreGraphics
import Foundation

/// Spiral galaxy with mood-driven color grading — port of themes/ring.js.
final class VortexTheme: Theme {
    let id = "ring"
    let name = "VORTEX"
    let palette = Palette(bg: "#0a0a0a", accent: "#e0a458", dim: "#5a4a38")

    private static let count = 2400
    private static let arms = 3
    private static let galaxyRadius: Double = 4.2
    private static let twist: Double = 4.5

    private var dist = [Double](repeating: 0, count: count)
    private var baseAngle = [Double](repeating: 0, count: count)
    private var scatter = [Double](repeating: 0, count: count)
    private var phase = [Double](repeating: 0, count: count)
    private var speed = [Double](repeating: 0, count: count)
    private var haze = [Double](repeating: 0, count: count)

    private var frame = Frame()
    private var rotation: Double = 0
    private var bassAvg: Float = 0
    private var pulse: Double = 0
    private var bassSm: CGFloat = 0
    private var trebSm: CGFloat = 0
    private var energySm: CGFloat = 0

    private let amber = RGB(0xe0a458)
    private let dim = RGB(0x5a4a38)
    private let ember = RGB(0xff4b2e)
    private let ice = RGB(0xa8d8ff)
    private let violet = RGB(0xb46bff)

    init() {
        for i in 0..<Self.count {
            let d = pow(Double.random(in: 0...1), 0.6)
            dist[i] = d
            let isField = Double.random(in: 0...1) < 0.45
            haze[i] = isField ? 1 : 0
            if isField {
                baseAngle[i] = Double.random(in: 0...(2 * .pi))
                scatter[i] = Double.random(in: -0.45...0.45) * d * 2
            } else {
                let arm = Double(i % Self.arms)
                baseAngle[i] = (arm / Double(Self.arms)) * 2 * .pi
                    + Double.random(in: -0.5...0.5) * (0.5 + d * 0.6)
                scatter[i] = Double.random(in: -0.25...0.25) * d * 2
            }
            phase[i] = Double.random(in: 0...(2 * .pi))
            speed[i] = 1.5 + Double.random(in: 0...4)
        }
    }

    func update(frame: Frame) {
        self.frame = frame
        let dt = frame.dt

        bassAvg += (frame.bass - bassAvg) * Float(min(dt * 2, 1))
        if frame.bass > 0.3 && frame.bass > bassAvg * 1.4 { pulse = 1 }
        pulse = max(pulse - dt * 1.2, 0)

        rotation += (0.12 + Double(frame.mid) * 1.1) * dt

        let ease = CGFloat(min(dt * 0.8, 1))
        bassSm += (CGFloat(frame.bass) - bassSm) * ease
        trebSm += (CGFloat(frame.treble) - trebSm) * ease
        energySm += (CGFloat(frame.level) - energySm) * ease
    }

    func draw(in ctx: CGContext, size: CGSize) {
        ctx.setFillColor(RGB(0x0a0a0a).cgColor())
        ctx.fill(CGRect(origin: .zero, size: size))

        let time = frame.time
        let w = size.width
        let h = size.height
        let cx = w / 2
        let cy = h / 2
        let focal = min(w, h) * 0.9

        // Mood tint
        var tint = amber
        tint = tint.lerp(ember, min(bassSm * 1.6, 1))
        tint = tint.lerp(ice, min(trebSm * 1.4, 0.8))
        var edge = dim
        edge = edge.lerp(violet, min(energySm * 1.8, 0.7))
        let idleDrift = 0.1 + 0.1 * sin(time * 0.15)
        tint = tint.lerp(violet, CGFloat(idleDrift) * (1 - min(energySm * 3, 1)))

        // Camera: orbits the disc, tilted down
        let camAngle = time * 0.08
        let tiltY = 0.42 + 0.12 * sin(time * 0.21)
        let cosA = cos(camAngle), sinA = sin(camAngle)
        let cosT = cos(tiltY), sinT = sin(tiltY)

        let breath = 1 + 0.04 * sin(time * 0.6) + Double(frame.bass) * 0.25
        let pulseFront = 1 - pulse
        ctx.setBlendMode(.plusLighter)

        for i in 0..<Self.count {
            let d = dist[i]
            let bin = Double(frame.bins[min(Int(d * 200), 255)])
            let lift = bin * bin * 1.4

            let angle = baseAngle[i] + d * Self.twist + rotation * (1.6 - d)
            let r = (d * Self.galaxyRadius + scatter[i]) * breath

            var x = cos(angle) * r
            var y = lift * (i % 2 == 0 ? 1.0 : -1.0)
                + 0.06 * sin(time * speed[i] * 0.3 + phase[i])
            var z = sin(angle) * r

            // Orbit (rotate about Y), then tilt (rotate about X)
            let rx = x * cosA - z * sinA
            let rz = x * sinA + z * cosA
            x = rx
            z = rz
            let ry = y * cosT - z * sinT
            let rz2 = y * sinT + z * cosT
            y = ry
            z = rz2

            let depth = z + 8
            guard depth > 1 else { continue }
            let scale = focal / (depth * 60)
            let sx = cx + CGFloat(x) * focal / CGFloat(depth) * 0.9
            let sy = cy + CGFloat(y) * focal / CGFloat(depth) * 0.9

            let twinkle = 0.5 + 0.5 * sin(time * speed[i] + phase[i])
            var glow = (1 - d) * 0.55 + 0.25 + twinkle * Double(frame.treble) * 0.6 + lift * 0.5
            glow *= 1 - haze[i] * 0.55
            let frontDist = abs(d - pulseFront)
            if pulse > 0 && frontDist < 0.12 {
                glow += (1 - frontDist / 0.12) * pulse * 0.9
            }
            let t = CGFloat(min(glow, 1.6))
            let color = edge.lerp(tint, t)
            // Perspective point size: stars are fine dots that swell only slightly
            // up close. (scale ≈ focal/(depth·60), so ~1–3px across the disc.)
            let dotSize = max(scale * 1.7, 0.8)
            ctx.setFillColor(color.cgColor(alpha: min(0.3 + t * 0.5, 1)))
            ctx.fillEllipse(in: CGRect(x: sx - dotSize / 2, y: sy - dotSize / 2, width: dotSize, height: dotSize))
        }

        // Core glow swelling with bass
        let coreR = (min(w, h) * 0.09) * (1 + CGFloat(frame.bass) * 0.9)
        let colors = [tint.cgColor(alpha: 0.9), tint.cgColor(alpha: 0)] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            ctx.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                endCenter: CGPoint(x: cx, y: cy), endRadius: coreR,
                options: []
            )
        }
        ctx.setBlendMode(.normal)
    }
}
