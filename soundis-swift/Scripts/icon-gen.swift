import AppKit
import CoreGraphics
import Foundation

// Renders the Soundis app icon (deep-space squircle + spiral galaxy) to a PNG.
// Usage: swift icon-gen.swift <out.png>

let size = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { fatalError() }
let W = CGFloat(size)

func hsb(_ h: Double, _ s: Double, _ b: Double, _ a: CGFloat) -> CGColor {
    let s = max(0, min(s, 1)), b = max(0, min(b, 1))
    let hh = (h - floor(h)) * 6, i = Int(hh) % 6, f = hh - floor(hh)
    let p = b * (1 - s), q = b * (1 - s * f), t = b * (1 - s * (1 - f))
    let (r, g, bl): (Double, Double, Double)
    switch i {
    case 0: (r, g, bl) = (b, t, p); case 1: (r, g, bl) = (q, b, p)
    case 2: (r, g, bl) = (p, b, t); case 3: (r, g, bl) = (p, q, b)
    case 4: (r, g, bl) = (t, p, b); default: (r, g, bl) = (b, p, q)
    }
    return CGColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(bl), alpha: a)
}

// Squircle (rounded-rect) mask with a small margin, transparent outside.
let inset: CGFloat = 36
let rect = CGRect(x: inset, y: inset, width: W - 2 * inset, height: W - 2 * inset)
let radius = (W - 2 * inset) * 0.2237
let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
ctx.addPath(squircle); ctx.clip()

// Deep-space background: dark violet core → near-black edge.
if let g = CGGradient(colorsSpace: cs,
                      colors: [CGColor(red: 0.11, green: 0.08, blue: 0.18, alpha: 1),
                               CGColor(red: 0.05, green: 0.04, blue: 0.09, alpha: 1),
                               CGColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1)] as CFArray,
                      locations: [0, 0.55, 1]) {
    ctx.drawRadialGradient(g, startCenter: CGPoint(x: W / 2, y: W * 0.54), startRadius: 0,
                           endCenter: CGPoint(x: W / 2, y: W * 0.54), endRadius: W * 0.75,
                           options: [.drawsAfterEndLocation])
}

let cx = W / 2, cy = W / 2
let maxR = W * 0.34
let tilt: CGFloat = 0.5          // vertical squash → viewed at an angle
let rot = -0.42                  // slight roll
let cosR = CGFloat(cos(rot)), sinR = CGFloat(sin(rot))

ctx.setBlendMode(.plusLighter)

// Faint sprinkle of distant background stars (outside the galaxy).
for _ in 0..<90 {
    let a = Double.random(in: 0...(2 * .pi)), rr = Double.random(in: 0...1)
    let rad = (0.5 + 0.5 * rr) * Double(W) * 0.44
    let px = CGFloat(cos(a) * rad), py = CGFloat(sin(a) * rad)
    let d = max(CGFloat.random(in: 1.2...2.6), 1)
    ctx.setFillColor(CGColor(red: 0.8, green: 0.85, blue: 1, alpha: CGFloat.random(in: 0.15...0.4)))
    ctx.fillEllipse(in: CGRect(x: cx + px - d, y: cy + py - d, width: d * 2, height: d * 2))
}

// Spiral galaxy: 3 arms + field, warm gold core → cyan/violet rim.
let arms = 3, twist = 3.5, count = 2800
for i in 0..<count {
    let d = pow(Double.random(in: 0...1), 0.5)
    let isField = Double.random(in: 0...1) < 0.4
    let baseAngle: Double = isField
        ? Double.random(in: 0...(2 * .pi))
        : Double(i % arms) / Double(arms) * 2 * .pi + Double.random(in: -0.35...0.35) * (0.4 + d * 0.6)
    let angle = baseAngle + d * twist
    let scatter = Double.random(in: -0.05...0.05) * Double(maxR)
    let r = d * Double(maxR) + scatter
    var px = CGFloat(cos(angle) * r)
    var py = CGFloat(sin(angle) * r) * tilt
    let rx = px * cosR - py * sinR, ry = px * sinR + py * cosR
    px = rx; py = ry
    let hue = 0.11 + d * 0.52                       // gold → cyan/blue outward
    let sat = 0.35 + d * 0.5
    let bri = max(1.0 - d * 0.4, 0.55)
    let alpha = CGFloat(isField ? 0.45 : 0.92) * (1 - CGFloat(d) * 0.35)
    let dot = max(CGFloat(6.0 * (1 - d * 0.68)), 1.7)
    ctx.setFillColor(hsb(hue, sat, bri, alpha))
    ctx.fillEllipse(in: CGRect(x: cx + px - dot / 2, y: cy + py - dot / 2, width: dot, height: dot))
}

// Core bloom (elliptical, aligned to the tilt): white-hot → gold → transparent.
ctx.saveGState()
ctx.translateBy(x: cx, y: cy); ctx.rotate(by: CGFloat(rot)); ctx.scaleBy(x: 1, y: tilt)
if let g = CGGradient(colorsSpace: cs,
                      colors: [CGColor(red: 1, green: 0.99, blue: 0.94, alpha: 1),
                               CGColor(red: 1, green: 0.82, blue: 0.45, alpha: 0.8),
                               CGColor(red: 1, green: 0.55, blue: 0.2, alpha: 0.25),
                               CGColor(red: 1, green: 0.4, blue: 0.15, alpha: 0)] as CFArray,
                      locations: [0, 0.28, 0.6, 1]) {
    ctx.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero,
                           endRadius: maxR * 0.62, options: [])
}
ctx.restoreGState()
ctx.setBlendMode(.normal)

guard let img = ctx.makeImage() else { fatalError() }
let rep = NSBitmapImageRep(cgImage: img)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError() }
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote \(CommandLine.arguments[1])")
