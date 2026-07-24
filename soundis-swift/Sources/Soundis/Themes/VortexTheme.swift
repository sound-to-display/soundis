import CoreGraphics
import Foundation

/// Spiral galaxy with mood-driven color grading — port of themes/ring.js.
/// Beats punch a hot core flare and jolt the camera; energy speeds the orbit
/// and widens the sway; treble makes the stars shimmer and lift.
final class VortexTheme: Theme {
    let id = "ring"
    let name = "VORTEX"
    let palette = Palette(bg: "#0a0a0a", accent: "#e0a458", dim: "#5a4a38")

    private static let count = 6500
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
    private var camOrbit: Double = 0
    private var bassAvg: Float = 0
    private var pulse: Double = 0          // shockwave front, slow decay
    private var beatKick: Double = 0       // camera jolt, fast decay
    private var coreFlare: CGFloat = 0     // hot core burst, fast decay
    private var bassSm: CGFloat = 0
    private var trebSm: CGFloat = 0
    private var energySm: CGFloat = 0
    private var density: CGFloat = 0.5   // 0…1: star count + inverse dot size

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
        if frame.bass > 0.34 && frame.bass > bassAvg * 1.5 {
            pulse = 1
            beatKick = 1
            coreFlare = 1
        }
        pulse = max(pulse - dt * 1.2, 0)
        beatKick = max(beatKick - dt * 3.5, 0)
        coreFlare = max(coreFlare - dt * 2.6, 0)

        let ease = CGFloat(min(dt * 0.8, 1))
        bassSm += (CGFloat(frame.bass) - bassSm) * ease
        trebSm += (CGFloat(frame.treble) - trebSm) * ease
        energySm += (CGFloat(frame.level) - energySm) * ease

        // Stars spin harder with mids; the whole disc orbits faster when loud.
        rotation += (0.12 + Double(frame.mid) * 1.2) * dt
        camOrbit += (0.08 + Double(energySm) * 0.6) * dt
    }

    func setDensity(_ value: CGFloat) { density = max(0, min(value, 1)) }

    func draw(in ctx: CGContext, size: CGSize) {
        ctx.setFillColor(RGB(0x0a0a0a).cgColor())
        ctx.fill(CGRect(origin: .zero, size: size))

        let time = frame.time
        let w = size.width, h = size.height
        let focal = min(w, h) * 0.9
        let e = Double(energySm)

        // Dynamic camera position: gentle idle sway, a wide swing when loud,
        // and a sharp jolt on every detected beat. Stars + core share it.
        let cxS = w / 2 + CGFloat(sin(time * 0.3) * 8 + e * sin(time * 0.9) * 19 + beatKick * cos(time * 32) * 8)
        let cyS = h / 2 + CGFloat(cos(time * 0.23) * 6 + e * cos(time * 1.15) * 15 + beatKick * sin(time * 27) * 8)

        // Palette: a hue that drifts slowly through the spectrum — warmed by bass,
        // cooled by treble. Each star further shifts hue by its distance, so the
        // disc shows a spread of colors at once instead of one flat tone.
        let baseHue = 0.08 + time * 0.015 - Double(bassSm) * 0.06 + Double(trebSm) * 0.14
        let coreColor = RGB.hsb(baseHue + 0.02, 0.45 + Double(energySm) * 0.3, 1)

        // Camera: orbit accelerates with energy, tilt swings, frame rolls a little.
        let camAngle = camOrbit
        let tiltY = 0.42 + 0.12 * sin(time * 0.21) + e * 0.12 * sin(time * 0.5)
        let cosA = cos(camAngle), sinA = sin(camAngle)
        let cosT = cos(tiltY), sinT = sin(tiltY)
        let roll = e * 0.10 * sin(time * 0.6) + beatKick * 0.03 * sin(time * 22)
        let cosR = CGFloat(cos(roll)), sinR = CGFloat(sin(roll))

        let breath = 1 + 0.04 * sin(time * 0.6) + Double(frame.bass) * 0.26 + pulse * 0.12
        let pulseFront = 1 - pulse
        ctx.setBlendMode(.plusLighter)

        // Density: high → the disc fills up with many small stars (촘촘); low → few
        // bigger ones (띄엄띄엄). Dot size and alpha drop as it packs so the dense
        // centre stays crisp instead of blowing out to white.
        let drawn = Int(Double(Self.count) * (0.07 + Double(density) * 0.93))
        let sizeFactor = 1.4 - density * 0.55
        let densityAlpha = 1 - density * 0.12
        for i in 0..<drawn {
            let d = dist[i]
            let bin = Double(frame.bins[min(Int(d * 200), 255)])
            let lift = bin * bin * 1.4 + pulse * 0.15

            let angle = baseAngle[i] + d * Self.twist + rotation * (1.6 - d)
            let shimmer = Double(trebSm) * 0.15 * sin(time * speed[i] + phase[i])
            let r = (d * Self.galaxyRadius + scatter[i]) * breath + shimmer

            var x = cos(angle) * r
            var y = lift * (i % 2 == 0 ? 1.0 : -1.0)
                + (0.06 + Double(trebSm) * 0.3) * sin(time * speed[i] * 0.3 + phase[i])
            var z = sin(angle) * r

            // Orbit (rotate about Y), then tilt (rotate about X)
            let rx = x * cosA - z * sinA
            let rz = x * sinA + z * cosA
            x = rx; z = rz
            let ry = y * cosT - z * sinT
            let rz2 = y * sinT + z * cosT
            y = ry; z = rz2

            let depth = z + 8
            guard depth > 1 else { continue }
            let scale = focal / (depth * 60)
            let dx = CGFloat(x) * focal / CGFloat(depth) * 0.9
            let dy = CGFloat(y) * focal / CGFloat(depth) * 0.9
            let sx = cxS + dx * cosR - dy * sinR
            let sy = cyS + dx * sinR + dy * cosR

            let twinkle = 0.5 + 0.5 * sin(time * speed[i] + phase[i])
            var glow = (1 - d) * 0.55 + 0.25 + twinkle * Double(frame.treble) * 0.7 + lift * 0.5
            glow *= 1 - haze[i] * 0.55
            let frontDist = abs(d - pulseFront)
            if pulse > 0 && frontDist < 0.12 {
                glow += (1 - frontDist / 0.12) * pulse * 0.8
            }
            let g = CGFloat(min(glow, 1.6))
            // Hue drifts globally and spreads with distance (+ a touch per arm),
            // so the galaxy shows many colours at once; brighter stars are more vivid.
            let hue = baseHue + d * 0.42 + Double(i % Self.arms) * 0.03
            let sat = min(0.45 + Double(energySm) * 0.4 + Double(g) * 0.2, 0.95) * (1 - haze[i] * 0.35)
            let color = RGB.hsb(hue, sat, min(0.32 + Double(g) * 0.62, 1))
            let dotSize = max(scale * 1.7 * sizeFactor, 0.6)
            ctx.setFillColor(color.cgColor(alpha: min(0.3 + g * 0.5, 1) * densityAlpha))
            ctx.fillEllipse(in: CGRect(x: sx - dotSize / 2, y: sy - dotSize / 2, width: dotSize, height: dotSize))
        }

        // Core: a soft, tilted-elliptical bloom built from layered, drifting lobes
        // so it reads as a hazy galactic core, not a hard drawn circle.
        let base = min(w, h)
        let coreR = base * (0.06 + bassSm * 0.10 + CGFloat(pulse) * 0.06)
        let squash: CGFloat = 0.46 + 0.06 * CGFloat(sin(time * 0.27))
        let a = CGFloat(roll)
        let wob = coreR * 0.18
        bloom(ctx, at: CGPoint(x: cxS + CGFloat(sin(time * 0.6)) * wob,
                               y: cyS + CGFloat(cos(time * 0.5)) * wob * squash),
              radius: coreR * 3.0, squash: squash, angle: a, color: coreColor, peak: 0.20)
        bloom(ctx, at: CGPoint(x: cxS - CGFloat(sin(time * 0.43)) * wob * 0.6,
                               y: cyS + CGFloat(sin(time * 0.37)) * wob * 0.5),
              radius: coreR * 1.7, squash: squash * 0.92, angle: a, color: coreColor, peak: 0.40)
        bloom(ctx, at: CGPoint(x: cxS, y: cyS), radius: coreR * 0.9, squash: squash * 0.85,
              angle: a, color: coreColor.lerp(RGB(0xffffff), 0.22), peak: 0.55)

        // Beat flare: a hot, soft burst sharing the core's elliptical shape.
        if coreFlare > 0.01 {
            let hot = coreColor.lerp(RGB(0xffffff), 0.6)
            bloom(ctx, at: CGPoint(x: cxS, y: cyS), radius: base * (0.11 + CGFloat(pulse) * 0.08),
                  squash: squash, angle: a, color: hot, peak: 0.5 * coreFlare)
        }
        ctx.setBlendMode(.normal)
    }

    /// Soft elliptical bloom with a gentle multi-stop falloff (no hard disc edge).
    private func bloom(_ ctx: CGContext, at c: CGPoint, radius r: CGFloat,
                       squash: CGFloat, angle: CGFloat, color: RGB, peak: CGFloat) {
        guard r > 1, peak > 0.001 else { return }
        let colors = [
            color.cgColor(alpha: peak),
            color.cgColor(alpha: peak * 0.5),
            color.cgColor(alpha: peak * 0.16),
            color.cgColor(alpha: 0),
        ] as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors, locations: [0, 0.3, 0.6, 1]) else { return }
        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y)
        ctx.rotate(by: angle)
        ctx.scaleBy(x: 1, y: squash)
        ctx.drawRadialGradient(g, startCenter: .zero, startRadius: 0,
                               endCenter: .zero, endRadius: r, options: [])
        ctx.restoreGState()
    }
}

extension RGB {
    /// HSB → RGB. h wraps around 1.0; s and b are clamped to 0…1.
    static func hsb(_ h: Double, _ s: Double, _ b: Double) -> RGB {
        let s = max(0, min(s, 1)), b = max(0, min(b, 1))
        let hh = (h - floor(h)) * 6
        let i = Int(hh) % 6
        let f = hh - floor(hh)
        let p = b * (1 - s), q = b * (1 - s * f), t = b * (1 - s * (1 - f))
        let (r, gr, bl): (Double, Double, Double)
        switch i {
        case 0: (r, gr, bl) = (b, t, p)
        case 1: (r, gr, bl) = (q, b, p)
        case 2: (r, gr, bl) = (p, b, t)
        case 3: (r, gr, bl) = (p, q, b)
        case 4: (r, gr, bl) = (t, p, b)
        default: (r, gr, bl) = (b, p, q)
        }
        return RGB(r: CGFloat(r), g: CGFloat(gr), b: CGFloat(bl))
    }
}
