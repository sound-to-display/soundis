import CoreGraphics
import Foundation

/// Spiral galaxy with mood-driven color grading — port of themes/ring.js.
/// Beats punch a hot core flare and jolt the camera; energy speeds the orbit
/// and widens the sway; treble makes the stars shimmer and lift.
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
    private var camOrbit: Double = 0
    private var bassAvg: Float = 0
    private var pulse: Double = 0          // shockwave front, slow decay
    private var beatKick: Double = 0       // camera jolt, fast decay
    private var coreFlare: CGFloat = 0     // hot core burst, fast decay
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
        if frame.bass > 0.28 && frame.bass > bassAvg * 1.35 {
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
        rotation += (0.12 + Double(frame.mid) * 1.8) * dt
        camOrbit += (0.08 + Double(energySm) * 1.1) * dt
    }

    func draw(in ctx: CGContext, size: CGSize) {
        ctx.setFillColor(RGB(0x0a0a0a).cgColor())
        ctx.fill(CGRect(origin: .zero, size: size))

        let time = frame.time
        let w = size.width, h = size.height
        let focal = min(w, h) * 0.9
        let e = Double(energySm)

        // Dynamic camera position: gentle idle sway, a wide swing when loud,
        // and a sharp jolt on every detected beat. Stars + core share it.
        let cxS = w / 2 + CGFloat(sin(time * 0.3) * 8 + e * sin(time * 0.9) * 34 + beatKick * cos(time * 32) * 16)
        let cyS = h / 2 + CGFloat(cos(time * 0.23) * 6 + e * cos(time * 1.15) * 26 + beatKick * sin(time * 27) * 16)

        // Mood tint
        var tint = amber
        tint = tint.lerp(ember, min(bassSm * 1.6, 1))
        tint = tint.lerp(ice, min(trebSm * 1.4, 0.8))
        var edge = dim
        edge = edge.lerp(violet, min(energySm * 1.8, 0.7))
        let idleDrift = 0.1 + 0.1 * sin(time * 0.15)
        tint = tint.lerp(violet, CGFloat(idleDrift) * (1 - min(energySm * 3, 1)))

        // Camera: orbit accelerates with energy, tilt swings, frame rolls a little.
        let camAngle = camOrbit
        let tiltY = 0.42 + 0.12 * sin(time * 0.21) + e * 0.22 * sin(time * 0.5)
        let cosA = cos(camAngle), sinA = sin(camAngle)
        let cosT = cos(tiltY), sinT = sin(tiltY)
        let roll = e * 0.18 * sin(time * 0.6) + beatKick * 0.05 * sin(time * 22)
        let cosR = CGFloat(cos(roll)), sinR = CGFloat(sin(roll))

        let breath = 1 + 0.04 * sin(time * 0.6) + Double(frame.bass) * 0.4 + pulse * 0.18
        let pulseFront = 1 - pulse
        ctx.setBlendMode(.plusLighter)

        for i in 0..<Self.count {
            let d = dist[i]
            let bin = Double(frame.bins[min(Int(d * 200), 255)])
            let lift = bin * bin * 2.0 + pulse * 0.25

            let angle = baseAngle[i] + d * Self.twist + rotation * (1.6 - d)
            let shimmer = Double(trebSm) * 0.15 * sin(time * speed[i] + phase[i])
            let r = (d * Self.galaxyRadius + scatter[i]) * breath + shimmer

            var x = cos(angle) * r
            var y = lift * (i % 2 == 0 ? 1.0 : -1.0)
                + (0.06 + Double(trebSm) * 0.5) * sin(time * speed[i] * 0.3 + phase[i])
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
            var glow = (1 - d) * 0.55 + 0.25 + twinkle * Double(frame.treble) * 0.9 + lift * 0.5
            glow *= 1 - haze[i] * 0.55
            let frontDist = abs(d - pulseFront)
            if pulse > 0 && frontDist < 0.12 {
                glow += (1 - frontDist / 0.12) * pulse * 1.1
            }
            let t = CGFloat(min(glow, 1.6))
            let color = edge.lerp(tint, t)
            let dotSize = max(scale * 1.7, 0.8)
            ctx.setFillColor(color.cgColor(alpha: min(0.3 + t * 0.5, 1)))
            ctx.fillEllipse(in: CGRect(x: sx - dotSize / 2, y: sy - dotSize / 2, width: dotSize, height: dotSize))
        }

        // Core glow: radius rides smoothed bass + the beat pulse, moving with the camera.
        let base = min(w, h)
        let coreR = base * (0.06 + bassSm * 0.14 + CGFloat(pulse) * 0.10)
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [tint.cgColor(alpha: 0.85), tint.cgColor(alpha: 0)] as CFArray,
                              locations: [0, 1]) {
            ctx.drawRadialGradient(g, startCenter: CGPoint(x: cxS, y: cyS), startRadius: 0,
                                   endCenter: CGPoint(x: cxS, y: cyS), endRadius: coreR, options: [])
        }
        // Beat flare: a hot white-gold burst punched on each detected beat.
        if coreFlare > 0.01 {
            let hot = tint.lerp(RGB(0xffffff), 0.65)
            let flareR = base * (0.10 + CGFloat(pulse) * 0.12)
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [hot.cgColor(alpha: 0.9 * coreFlare), hot.cgColor(alpha: 0)] as CFArray,
                                  locations: [0, 1]) {
                ctx.drawRadialGradient(g, startCenter: CGPoint(x: cxS, y: cyS), startRadius: 0,
                                       endCenter: CGPoint(x: cxS, y: cyS), endRadius: flareR, options: [])
            }
        }
        ctx.setBlendMode(.normal)
    }
}
