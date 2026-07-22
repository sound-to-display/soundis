import CoreGraphics
import Foundation

/// Strip-chart recorder — port of themes/console.js. Aged paper scrolls left
/// while three spring-loaded ink pens (BASS / MID / TREB) trace each band.
final class SeismoTheme: Theme {
    let id = "console"
    let name = "SEISMO"
    let palette = Palette(bg: "#241a12", accent: "#e8873a", dim: "#7a5c40")

    private static let springK: Double = 120
    private static let springD: Double = 8
    private static let history = 900
    private static let penCount = 3

    private struct Pen { var angle: Double = 0; var velocity: Double = 0 }
    private struct PenConfig { let label: String; let color: RGB }
    private let configs = [
        PenConfig(label: "BASS", color: RGB(0xe8873a)),
        PenConfig(label: "MID", color: RGB(0xc9a227)),
        PenConfig(label: "TREB", color: RGB(0xb0512e)),
    ]

    private var pens = [Pen](repeating: Pen(), count: penCount)
    private var trace = [Double](repeating: 0, count: history * penCount)
    private var head = 0
    private var filled = 0
    private var paperScroll: Double = 0
    private var frame = Frame()

    private let ink = RGB(0x2a1c10)
    private let chrome = RGB(0x7a5c40)
    private let paper = RGB(0xefe3c8)
    private let lamp = RGB(0xff6b35)

    private func step(_ pen: inout Pen, target: Double, dt: Double) {
        let accel = Self.springK * (target - pen.angle) - Self.springD * pen.velocity
        pen.velocity += accel * dt
        pen.angle += pen.velocity * dt
    }

    func update(frame: Frame) {
        self.frame = frame
        let dt = frame.dt
        let time = frame.time

        let targets = [
            max(Double(frame.bass) + 0.02 * sin(time * 1.1), 0),
            max(Double(frame.mid) + 0.02 * sin(time * 1.6), 0),
            max(Double(frame.treble) + 0.02 * sin(time * 2.1), 0),
        ]
        for p in 0..<Self.penCount {
            step(&pens[p], target: min(targets[p], 1.1), dt: dt)
            trace[head * Self.penCount + p] = pens[p].angle
        }
        head = (head + 1) % Self.history
        filled = min(filled + 1, Self.history)
        paperScroll += (30 + Double(frame.level) * 160) * dt
    }

    func draw(in ctx: CGContext, size: CGSize) {
        let w = size.width, h = size.height

        ctx.setFillColor(RGB(0x241a12).cgColor())
        ctx.fill(CGRect(origin: .zero, size: size))

        let paperX = w * 0.06, paperW = w * 0.78
        let paperY = h * 0.1, paperH = h * 0.78
        ctx.setFillColor(paper.cgColor())
        ctx.fill(CGRect(x: paperX, y: paperY, width: paperW, height: paperH))

        // Scrolling chart grid
        let gridGap: CGFloat = 26
        ctx.setStrokeColor(CGColor(red: 160.0 / 255, green: 120.0 / 255, blue: 70.0 / 255, alpha: 0.35))
        ctx.setLineWidth(1)
        var gx = paperX + paperW - CGFloat(paperScroll.truncatingRemainder(dividingBy: Double(gridGap)))
        while gx > paperX {
            ctx.move(to: CGPoint(x: gx, y: paperY))
            ctx.addLine(to: CGPoint(x: gx, y: paperY + paperH))
            gx -= gridGap
        }
        ctx.strokePath()

        let laneH = paperH / CGFloat(Self.penCount)
        ctx.setStrokeColor(CGColor(red: 160.0 / 255, green: 120.0 / 255, blue: 70.0 / 255, alpha: 0.55))
        for p in 0...Self.penCount {
            let y = paperY + laneH * CGFloat(p)
            ctx.move(to: CGPoint(x: paperX, y: y))
            ctx.addLine(to: CGPoint(x: paperX + paperW, y: y))
        }
        ctx.strokePath()

        // Ink traces (newest sample under the pen at the right edge)
        let step = max(paperW / CGFloat(max(filled, 1)), 1.2)
        for p in 0..<Self.penCount {
            let laneTop = paperY + laneH * CGFloat(p)
            ctx.setStrokeColor(configs[p].color.cgColor())
            ctx.setLineWidth(1.8)
            ctx.beginPath()
            var moved = false
            for s in 0..<filled {
                let idx = (head - 1 - s + Self.history * 2) % Self.history
                let value = trace[idx * Self.penCount + p]
                let x = paperX + paperW - CGFloat(s) * step
                if x < paperX { break }
                let y = laneTop + laneH * 0.85 - CGFloat(min(value, 1.1)) * laneH * 0.7
                if !moved { ctx.move(to: CGPoint(x: x, y: y)); moved = true }
                else { ctx.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.strokePath()
        }

        // Pen arms + nibs + labels + overload lamps
        for p in 0..<Self.penCount {
            let laneTop = paperY + laneH * CGFloat(p)
            let nibY = laneTop + laneH * 0.85 - CGFloat(min(pens[p].angle, 1.1)) * laneH * 0.7
            let armX = paperX + paperW
            let pivotX = w * 0.92
            let pivotY = laneTop + laneH * 0.5

            ctx.setStrokeColor(ink.cgColor())
            ctx.setLineWidth(3)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: pivotX, y: pivotY))
            ctx.addLine(to: CGPoint(x: armX, y: nibY))
            ctx.strokePath()

            ctx.setFillColor(configs[p].color.cgColor())
            ctx.fillEllipse(in: CGRect(x: armX - 4, y: nibY - 4, width: 8, height: 8))
            ctx.setFillColor(ink.cgColor())
            ctx.fillEllipse(in: CGRect(x: pivotX - 6, y: pivotY - 6, width: 12, height: 12))

            drawText(configs[p].label, x: w * 0.885, y: laneTop + 14, size: 10, color: chrome)
            if pens[p].angle > 0.85 {
                ctx.setFillColor(lamp.cgColor())
                let lx = w * 0.9, ly = laneTop + laneH - 14
                ctx.fillEllipse(in: CGRect(x: lx - 5, y: ly - 5, width: 10, height: 10))
            }
        }

        // Machine chrome
        ctx.setStrokeColor(chrome.cgColor())
        ctx.setLineWidth(2)
        ctx.stroke(CGRect(x: paperX, y: paperY, width: paperW, height: paperH))
        let speed = Int(30 + Double(frame.level) * 160)
        drawText("CHART SPEED \(speed) mm/s", x: paperX, y: paperY + paperH + 20, size: 11, color: chrome)
    }
}
