# Galaxy Morphologies + Theme Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the single spiral galaxy into 6 selectable galaxy morphologies (SPIRAL, BARRED, ELLIPTICAL, IRREGULAR, RING, LENTICULAR) sharing one `GalaxyTheme` base, plus a Liquid Glass card-grid theme picker.

**Architecture:** Generalize `VortexTheme` into `GalaxyTheme` that draws stars from model-space base positions (`bx,by,bz` + `dist`,`spin`,`phase`,`speed`,`haze`) held in a `GalaxyStars` struct. A `Morphology` fills those arrays; each morphology becomes one `GalaxyTheme` instance. A SwiftUI `ThemePickerView` overlay selects any theme.

**Tech Stack:** Swift 6 (language mode 5), SwiftPM executable, AppKit + Core Graphics + SwiftUI (macOS 26).

## Global Constraints

- Swift tools 6.0, deployment target macOS 26.0 (`Package.swift` unchanged).
- Single executable target `Soundis`; no new targets. **No XCTest** — this is a GUI/graphics feature.
- **Verification = offscreen PNG capture** using existing hooks: `SOUNDIS_THEME=<i> SOUNDIS_DENSITY=<0..1> SOUNDIS_CAPTURE=<path> .build/debug/Soundis` renders that theme to a PNG with no audio/permission needed. Open the PNG and confirm the described shape.
- `swift build` MUST stay clean (0 errors) at the end of every task.
- App bundle is signed via `./Scripts/make-app.sh` (stable identity "Soundis Self-Signed"); only rebuild the bundle in the final task.
- Star pool per galaxy: `count = 6500`. Density maps `drawn = Int(count * (0.07 + density*0.93))`, `sizeFactor = 1.4 - density*0.55`, `densityAlpha = 1 - density*0.12` (copied from current VORTEX).
- Shared palette bg is `#0a0a0a` for every galaxy; per-morphology `accent`/`dim` only tint the Liquid Glass UI.

---

## File Structure

- Create `Sources/Soundis/Galaxy/GalaxyStars.swift` — per-star array container.
- Create `Sources/Soundis/Galaxy/Morphology.swift` — `Morphology` protocol + shared RNG helpers.
- Create `Sources/Soundis/Galaxy/GalaxyTheme.swift` — generalized theme (the current VortexTheme pipeline, positions sourced from `GalaxyStars`). Hosts `RGB.hsb` and the `bloom` helper.
- Create `Sources/Soundis/Galaxy/Morphologies/{Spiral,Barred,Elliptical,Irregular,Ring,Lenticular}Morphology.swift`.
- Delete `Sources/Soundis/Themes/VortexTheme.swift` (replaced by GalaxyTheme + SpiralMorphology).
- Modify `Sources/Soundis/Theme.swift` — `ThemeRegistry.makeThemes()` builds 6 galaxies + 4 existing; add `Theme.isGalaxy` default.
- Modify `Sources/Soundis/ControlsView.swift` — model fields (`pickerOpen`,`isGalaxy`,`themeList`,`currentIndex`,`onSelectTheme`), density shown for galaxies, host picker.
- Create `Sources/Soundis/ThemePickerView.swift` — SwiftUI card grid + static galaxy mini-icons.
- Modify `Sources/Soundis/App.swift` — populate model theme list / `isGalaxy` / `currentIndex`, wire `onSelectTheme`, Esc closes picker.
- Modify `Sources/Soundis/StageView.swift` — expose `themes` names + whether current theme is a galaxy (via `Theme.isGalaxy`).

---

## Task 1: GalaxyStars + Morphology + GalaxyTheme (SPIRAL reproduces VORTEX)

**Files:**
- Create: `Sources/Soundis/Galaxy/GalaxyStars.swift`
- Create: `Sources/Soundis/Galaxy/Morphology.swift`
- Create: `Sources/Soundis/Galaxy/GalaxyTheme.swift`
- Create: `Sources/Soundis/Galaxy/Morphologies/SpiralMorphology.swift`
- Modify: `Sources/Soundis/Theme.swift` (registry: replace `VortexTheme()` with `GalaxyTheme(SpiralMorphology())`)
- Delete: `Sources/Soundis/Themes/VortexTheme.swift`

**Interfaces:**
- Produces `struct GalaxyStars` (arrays `bx,by,bz,dist,spin,phase,speed,haze: [Double]`, `init(count:)`).
- Produces `protocol Morphology { var id: String; var name: String; var accentHex: String; func generate(into: inout GalaxyStars, count: Int) }`.
- Produces `final class GalaxyTheme: Theme` with `init(_ morphology: Morphology)`, and moves `RGB.hsb` + `bloom` here.
- Produces `struct SpiralMorphology: Morphology`.

- [ ] **Step 1: Create `GalaxyStars.swift`**

```swift
import Foundation

/// Per-star model-space data shared by every galaxy morphology.
/// Positions are in the galaxy's local frame (roughly within radius ~4.2).
struct GalaxyStars {
    var bx: [Double]; var by: [Double]; var bz: [Double]
    var dist: [Double]   // 0…1 radius: colour-hue spread + frame.bins lookup + glow
    var spin: [Double]   // Y-rotation weight applied to base pos over time
    var phase: [Double]; var speed: [Double]
    var haze: [Double]   // 0/1 field vs core (dims + desaturates)

    init(count: Int) {
        bx = .init(repeating: 0, count: count); by = .init(repeating: 0, count: count)
        bz = .init(repeating: 0, count: count); dist = .init(repeating: 0, count: count)
        spin = .init(repeating: 0, count: count); phase = .init(repeating: 0, count: count)
        speed = .init(repeating: 0, count: count); haze = .init(repeating: 0, count: count)
    }
}
```

- [ ] **Step 2: Create `Morphology.swift`**

```swift
import Foundation

/// A galaxy shape: fills every star's base position + attributes.
protocol Morphology {
    var id: String { get }
    var name: String { get }
    var accentHex: String { get }   // Liquid Glass UI tint only
    func generate(into s: inout GalaxyStars, count: Int)
}

/// Shared helpers for generators.
enum Gal {
    static func rand(_ lo: Double = 0, _ hi: Double = 1) -> Double { Double.random(in: lo...hi) }
    /// Approx. gaussian in [-1,1]-ish (sum of 3 uniforms).
    static func gauss() -> Double { (Double.random(in: -1...1) + Double.random(in: -1...1) + Double.random(in: -1...1)) / 1.7 }
    /// Uniform point direction on a unit sphere → (x,y,z).
    static func sphere() -> (Double, Double, Double) {
        let u = Double.random(in: -1...1), t = Double.random(in: 0...(2 * .pi)), s = (1 - u * u).squareRoot()
        return (s * cos(t), u, s * sin(t))
    }
}
```

- [ ] **Step 3: Create `SpiralMorphology.swift` (reproduces current VORTEX exactly)**

```swift
import Foundation

struct SpiralMorphology: Morphology {
    let id = "spiral", name = "SPIRAL", accentHex = "#e0a458"
    private let arms = 3, radius = 4.2, twist = 4.5

    func generate(into s: inout GalaxyStars, count: Int) {
        for i in 0..<count {
            let d = pow(Gal.rand(), 0.6)
            s.dist[i] = d
            let isField = Gal.rand() < 0.45
            s.haze[i] = isField ? 1 : 0
            let baseAngle: Double, scatter: Double
            if isField {
                baseAngle = Gal.rand(0, 2 * .pi)
                scatter = Gal.rand(-0.45, 0.45) * d * 2
            } else {
                let arm = Double(i % arms)
                baseAngle = (arm / Double(arms)) * 2 * .pi + Gal.rand(-0.5, 0.5) * (0.5 + d * 0.6)
                scatter = Gal.rand(-0.25, 0.25) * d * 2
            }
            let angle0 = baseAngle + d * twist       // arm shape baked in (was: + rotation*(1.6-d) at draw)
            let r0 = d * radius + scatter
            s.bx[i] = cos(angle0) * r0
            s.bz[i] = sin(angle0) * r0
            s.by[i] = 0
            s.spin[i] = 1.6 - d                      // inner spins faster (differential)
            s.phase[i] = Gal.rand(0, 2 * .pi)
            s.speed[i] = 1.5 + Gal.rand(0, 4)
        }
    }
}
```

- [ ] **Step 4: Create `GalaxyTheme.swift`** (current VortexTheme pipeline; positions from `GalaxyStars`)

```swift
import CoreGraphics
import Foundation

/// Audio-reactive galaxy renderer shared by all morphologies. Stars are drawn
/// from model-space base positions rotated over time by their `spin`, projected
/// with the same orbiting/tilting/rolling camera, hue-graded and density-scaled.
final class GalaxyTheme: Theme {
    let id: String
    let name: String
    let palette: Palette

    private static let count = 6500
    private var s: GalaxyStars

    private var frame = Frame()
    private var rotation: Double = 0
    private var camOrbit: Double = 0
    private var bassAvg: Float = 0
    private var pulse: Double = 0
    private var beatKick: Double = 0
    private var coreFlare: CGFloat = 0
    private var bassSm: CGFloat = 0
    private var trebSm: CGFloat = 0
    private var energySm: CGFloat = 0
    private var density: CGFloat = 0.5

    init(_ morphology: Morphology) {
        id = morphology.id
        name = morphology.name
        palette = Palette(bg: "#0a0a0a", accent: morphology.accentHex, dim: "#4a4a55")
        s = GalaxyStars(count: Self.count)
        morphology.generate(into: &s, count: Self.count)
    }

    var isGalaxy: Bool { true }

    func setDensity(_ value: CGFloat) { density = max(0, min(value, 1)) }

    func update(frame: Frame) {
        self.frame = frame
        let dt = frame.dt
        bassAvg += (frame.bass - bassAvg) * Float(min(dt * 2, 1))
        if frame.bass > 0.34 && frame.bass > bassAvg * 1.5 { pulse = 1; beatKick = 1; coreFlare = 1 }
        pulse = max(pulse - dt * 1.2, 0)
        beatKick = max(beatKick - dt * 3.5, 0)
        coreFlare = max(coreFlare - dt * 2.6, 0)
        let ease = CGFloat(min(dt * 0.8, 1))
        bassSm += (CGFloat(frame.bass) - bassSm) * ease
        trebSm += (CGFloat(frame.treble) - trebSm) * ease
        energySm += (CGFloat(frame.level) - energySm) * ease
        rotation += (0.12 + Double(frame.mid) * 1.2) * dt
        camOrbit += (0.08 + Double(energySm) * 0.6) * dt
    }

    func draw(in ctx: CGContext, size: CGSize) {
        ctx.setFillColor(RGB(0x0a0a0a).cgColor())
        ctx.fill(CGRect(origin: .zero, size: size))

        let time = frame.time
        let w = size.width, h = size.height
        let focal = min(w, h) * 0.9
        let e = Double(energySm)

        let cxS = w / 2 + CGFloat(sin(time * 0.3) * 8 + e * sin(time * 0.9) * 19 + beatKick * cos(time * 32) * 8)
        let cyS = h / 2 + CGFloat(cos(time * 0.23) * 6 + e * cos(time * 1.15) * 15 + beatKick * sin(time * 27) * 8)

        let baseHue = 0.08 + time * 0.015 - Double(bassSm) * 0.06 + Double(trebSm) * 0.14
        let coreColor = RGB.hsb(baseHue + 0.02, 0.45 + Double(energySm) * 0.3, 1)

        let camAngle = camOrbit
        let tiltY = 0.42 + 0.12 * sin(time * 0.21) + e * 0.12 * sin(time * 0.5)
        let cosA = cos(camAngle), sinA = sin(camAngle)
        let cosT = cos(tiltY), sinT = sin(tiltY)
        let roll = e * 0.10 * sin(time * 0.6) + beatKick * 0.03 * sin(time * 22)
        let cosR = CGFloat(cos(roll)), sinR = CGFloat(sin(roll))

        let breath = 1 + 0.04 * sin(time * 0.6) + Double(frame.bass) * 0.26 + pulse * 0.12
        let pulseFront = 1 - pulse
        ctx.setBlendMode(.plusLighter)

        let drawn = Int(Double(Self.count) * (0.07 + Double(density) * 0.93))
        let sizeFactor = 1.4 - density * 0.55
        let densityAlpha = 1 - density * 0.12
        for i in 0..<drawn {
            let d = s.dist[i]
            let bin = Double(frame.bins[min(Int(d * 200), 255)])
            let lift = bin * bin * 1.4 + pulse * 0.15

            // Differential spin about Y, then breath scale.
            let sp = rotation * s.spin[i]
            let cs = cos(sp), sn = sin(sp)
            var x = (s.bx[i] * cs - s.bz[i] * sn) * breath
            var z = (s.bx[i] * sn + s.bz[i] * cs) * breath
            var y = s.by[i] * breath
                + lift * (i % 2 == 0 ? 1.0 : -1.0)
                + (0.06 + Double(trebSm) * 0.3) * sin(time * s.speed[i] * 0.3 + s.phase[i])

            // Camera orbit about Y, then tilt about X.
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

            let twinkle = 0.5 + 0.5 * sin(time * s.speed[i] + s.phase[i])
            var glow = (1 - d) * 0.55 + 0.25 + twinkle * Double(frame.treble) * 0.7 + lift * 0.5
            glow *= 1 - s.haze[i] * 0.55
            let frontDist = abs(d - pulseFront)
            if pulse > 0 && frontDist < 0.12 { glow += (1 - frontDist / 0.12) * pulse * 0.8 }
            let g = CGFloat(min(glow, 1.6))
            let hue = baseHue + d * 0.42 + Double(i % 3) * 0.03
            let sat = min(0.45 + Double(energySm) * 0.4 + Double(g) * 0.2, 0.95) * (1 - s.haze[i] * 0.35)
            let color = RGB.hsb(hue, sat, min(0.32 + Double(g) * 0.62, 1))
            let dotSize = max(scale * 1.7 * sizeFactor, 0.6)
            ctx.setFillColor(color.cgColor(alpha: min(0.3 + g * 0.5, 1) * densityAlpha))
            ctx.fillEllipse(in: CGRect(x: sx - dotSize / 2, y: sy - dotSize / 2, width: dotSize, height: dotSize))
        }

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
        if coreFlare > 0.01 {
            let hot = coreColor.lerp(RGB(0xffffff), 0.6)
            bloom(ctx, at: CGPoint(x: cxS, y: cyS), radius: base * (0.11 + CGFloat(pulse) * 0.08),
                  squash: squash, angle: a, color: hot, peak: 0.5 * coreFlare)
        }
        ctx.setBlendMode(.normal)
    }

    private func bloom(_ ctx: CGContext, at c: CGPoint, radius r: CGFloat,
                       squash: CGFloat, angle: CGFloat, color: RGB, peak: CGFloat) {
        guard r > 1, peak > 0.001 else { return }
        let colors = [color.cgColor(alpha: peak), color.cgColor(alpha: peak * 0.5),
                      color.cgColor(alpha: peak * 0.16), color.cgColor(alpha: 0)] as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors, locations: [0, 0.3, 0.6, 1]) else { return }
        ctx.saveGState()
        ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: angle); ctx.scaleBy(x: 1, y: squash)
        ctx.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: r, options: [])
        ctx.restoreGState()
    }
}

extension RGB {
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
```

- [ ] **Step 5: Delete old VortexTheme, update registry**

Delete `Sources/Soundis/Themes/VortexTheme.swift`. In `Sources/Soundis/Theme.swift`, change `ThemeRegistry.makeThemes()` first entry from `VortexTheme()` to `GalaxyTheme(SpiralMorphology())`, and add the galaxy flag to the protocol:

```swift
// in protocol Theme { … }
    var isGalaxy: Bool { get }
// in extension Theme { … }
    var isGalaxy: Bool { false }
```

`makeThemes()` (final list set in Task 9) for now:
```swift
static func makeThemes() -> [Theme] {
    [GalaxyTheme(SpiralMorphology()), WarpTheme(), SeismoTheme(), RainTheme(), InvadersTheme()]
}
```

- [ ] **Step 6: Build**

Run: `swift build 2>&1 | grep -E 'error:|Build complete'`
Expected: `Build complete!`, no `error:`.

- [ ] **Step 7: Verify SPIRAL matches the old VORTEX**

```bash
SS=$(mktemp -d)
SOUNDIS_THEME=0 SOUNDIS_DENSITY=0.5 SOUNDIS_CAPTURE="$SS/spiral.png" .build/debug/Soundis
open "$SS/spiral.png"
```
Expected: an amber-cored spiral galaxy with 3 arms, hue spreading gold→green→cyan outward — visually the same as the current VORTEX at density 0.5. If it differs structurally, the base-position math in Step 3/4 is wrong; fix before continuing.

- [ ] **Step 8: Commit**

```bash
git add soundis/soundis-swift
git commit -m "soundis: extract GalaxyTheme base + SpiralMorphology (VORTEX unchanged)"
```

---

## Task 2: BarredMorphology

**Files:**
- Create: `Sources/Soundis/Galaxy/Morphologies/BarredMorphology.swift`
- Modify: `Sources/Soundis/Theme.swift` (insert `GalaxyTheme(BarredMorphology())` at index 1)

**Interfaces:** Consumes `GalaxyStars`, `Morphology`, `Gal`. Produces `struct BarredMorphology: Morphology`.

- [ ] **Step 1: Create `BarredMorphology.swift`**

```swift
import Foundation

/// Central bar with two trailing arms anchored at the bar tips.
struct BarredMorphology: Morphology {
    let id = "barred", name = "BARRED", accentHex = "#6fa8ff"
    private let radius = 4.2, barLen = 1.9, twist = 4.0

    func generate(into s: inout GalaxyStars, count: Int) {
        for i in 0..<count {
            s.phase[i] = Gal.rand(0, 2 * .pi)
            s.speed[i] = 1.5 + Gal.rand(0, 4)
            if Gal.rand() < 0.4 {
                // Bar: elongated along x, thin in z.
                let t = Gal.gauss()                 // -1…1 along the bar
                s.bx[i] = t * barLen
                s.bz[i] = Gal.rand(-0.35, 0.35)
                s.by[i] = Gal.rand(-0.2, 0.2)
                s.dist[i] = min(abs(t) * 0.45, 1)
                s.haze[i] = 0
                s.spin[i] = 1.3
            } else {
                // Arm from one of the two bar tips (angle 0 or π), spiralling out.
                let d = pow(Gal.rand(), 0.7)         // 0…1 along the arm
                let ang = (i % 2 == 0 ? 0.0 : .pi) + d * twist
                let r = barLen + d * (radius - barLen)
                let scat = Gal.rand(-0.3, 0.3) * (0.35 + d)
                s.bx[i] = cos(ang) * r + cos(ang + .pi / 2) * scat
                s.bz[i] = sin(ang) * r + sin(ang + .pi / 2) * scat
                s.by[i] = Gal.rand(-0.12, 0.12)
                s.dist[i] = min(0.4 + d * 0.6, 1)
                s.haze[i] = Gal.rand() < 0.3 ? 1 : 0
                s.spin[i] = 1.6 - s.dist[i]
            }
        }
    }
}
```

- [ ] **Step 2: Register at index 1**

In `makeThemes()`: `[GalaxyTheme(SpiralMorphology()), GalaxyTheme(BarredMorphology()), WarpTheme(), …]`.

- [ ] **Step 3: Build** — `swift build` → `Build complete!`.

- [ ] **Step 4: Verify** — `SOUNDIS_THEME=1 SOUNDIS_DENSITY=0.7 SOUNDIS_CAPTURE=$SS/barred.png .build/debug/Soundis; open $SS/barred.png`
Expected: a bright horizontal **bar** through the centre with **two arms** curling off its ends — clearly not a symmetric spiral.

- [ ] **Step 5: Commit** — `git add soundis/soundis-swift && git commit -m "soundis: add BARRED galaxy morphology"`

---

## Task 3: EllipticalMorphology

**Files:** Create `Sources/Soundis/Galaxy/Morphologies/EllipticalMorphology.swift`; Modify `Theme.swift` (index 2).

**Interfaces:** Produces `struct EllipticalMorphology: Morphology`.

- [ ] **Step 1: Create `EllipticalMorphology.swift`**

```swift
import Foundation

/// Smooth 3-D ellipsoid, dense centre → sparse edge, no arms.
struct EllipticalMorphology: Morphology {
    let id = "elliptical", name = "ELLIPTICAL", accentHex = "#ffcf6b"
    private let radius = 4.0

    func generate(into s: inout GalaxyStars, count: Int) {
        for i in 0..<count {
            let r0 = pow(Gal.rand(), 0.7) * radius        // concentrated toward centre
            let (dx, dy, dz) = Gal.sphere()
            s.bx[i] = dx * r0
            s.by[i] = dy * r0 * 0.7                        // flattened
            s.bz[i] = dz * r0
            s.dist[i] = min(r0 / radius, 1)
            s.haze[i] = Gal.rand() < 0.25 ? 1 : 0
            s.spin[i] = 0.4                                // slow rigid rotation
            s.phase[i] = Gal.rand(0, 2 * .pi)
            s.speed[i] = 1.5 + Gal.rand(0, 4)
        }
    }
}
```

- [ ] **Step 2: Register at index 2.** — `swift build`.
- [ ] **Step 3: Verify** — `SOUNDIS_THEME=2 … CAPTURE=$SS/ellip.png`. Expected: a smooth ellipsoidal **blob** of stars, bright dense centre fading evenly outward, **no arms/disc structure**.
- [ ] **Step 4: Commit** — `git commit -m "soundis: add ELLIPTICAL galaxy morphology"`

---

## Task 4: IrregularMorphology

**Files:** Create `…/IrregularMorphology.swift`; Modify `Theme.swift` (index 3).

**Interfaces:** Produces `struct IrregularMorphology: Morphology`.

- [ ] **Step 1: Create `IrregularMorphology.swift`**

```swift
import Foundation

/// Asymmetric clumps — a handful of star-forming knots scattered off-centre.
struct IrregularMorphology: Morphology {
    let id = "irregular", name = "IRREGULAR", accentHex = "#57e0c8"

    func generate(into s: inout GalaxyStars, count: Int) {
        struct Clump { let x, y, z, r: Double }
        let clumps = (0..<7).map { _ in
            Clump(x: Gal.rand(-2.8, 2.8), y: Gal.rand(-0.8, 0.8), z: Gal.rand(-2.8, 2.8), r: Gal.rand(0.6, 1.6))
        }
        for i in 0..<count {
            let c = clumps[i % clumps.count]
            s.bx[i] = c.x + Gal.gauss() * c.r
            s.by[i] = c.y + Gal.gauss() * c.r * 0.5
            s.bz[i] = c.z + Gal.gauss() * c.r
            let r = (s.bx[i] * s.bx[i] + s.bz[i] * s.bz[i]).squareRoot() / 4.2
            s.dist[i] = min(r, 1)
            s.haze[i] = Gal.rand() < 0.3 ? 1 : 0
            s.spin[i] = 0.6
            s.phase[i] = Gal.rand(0, 2 * .pi)
            s.speed[i] = 1.5 + Gal.rand(0, 4)
        }
    }
}
```

- [ ] **Step 2: Register at index 3.** — `swift build`.
- [ ] **Step 3: Verify** — `SOUNDIS_THEME=3 … CAPTURE=$SS/irreg.png`. Expected: several **off-centre clumps** of stars with no symmetry or central core dominance.
- [ ] **Step 4: Commit** — `git commit -m "soundis: add IRREGULAR galaxy morphology"`

---

## Task 5: RingMorphology

**Files:** Create `…/RingMorphology.swift`; Modify `Theme.swift` (index 4).

**Interfaces:** Produces `struct RingMorphology: Morphology`.

- [ ] **Step 1: Create `RingMorphology.swift`**

```swift
import Foundation

/// Bright annulus with a faint, near-empty interior.
struct RingMorphology: Morphology {
    let id = "ring", name = "RING", accentHex = "#c69bff"
    private let ringR = 3.2

    func generate(into s: inout GalaxyStars, count: Int) {
        for i in 0..<count {
            let ang = Gal.rand(0, 2 * .pi)
            let onRing = Gal.rand() < 0.82
            let r0: Double
            if onRing {
                r0 = ringR + Gal.gauss() * 0.6
                s.haze[i] = 0
            } else {
                r0 = Gal.rand() * ringR * 0.7          // faint interior
                s.haze[i] = 1
            }
            s.bx[i] = cos(ang) * r0
            s.bz[i] = sin(ang) * r0
            s.by[i] = Gal.rand(-0.15, 0.15)
            s.dist[i] = min(r0 / (ringR + 0.6), 1)
            s.spin[i] = 1.0
            s.phase[i] = Gal.rand(0, 2 * .pi)
            s.speed[i] = 1.5 + Gal.rand(0, 4)
        }
    }
}
```

- [ ] **Step 2: Register at index 4.** — `swift build`.
- [ ] **Step 3: Verify** — `SOUNDIS_THEME=4 … CAPTURE=$SS/ring.png`. Expected: a bright **ring/annulus** with a darker centre.
- [ ] **Step 4: Commit** — `git commit -m "soundis: add RING galaxy morphology"`

---

## Task 6: LenticularMorphology

**Files:** Create `…/LenticularMorphology.swift`; Modify `Theme.swift` (index 5).

**Interfaces:** Produces `struct LenticularMorphology: Morphology`.

- [ ] **Step 1: Create `LenticularMorphology.swift`**

```swift
import Foundation

/// Smooth armless disc with a bright spherical central bulge.
struct LenticularMorphology: Morphology {
    let id = "lenticular", name = "LENTICULAR", accentHex = "#d6d9e6"
    private let radius = 4.0

    func generate(into s: inout GalaxyStars, count: Int) {
        for i in 0..<count {
            s.phase[i] = Gal.rand(0, 2 * .pi)
            s.speed[i] = 1.5 + Gal.rand(0, 4)
            if Gal.rand() < 0.35 {
                // Spherical bulge.
                let r0 = pow(Gal.rand(), 0.7) * radius * 0.4
                let (dx, dy, dz) = Gal.sphere()
                s.bx[i] = dx * r0; s.by[i] = dy * r0 * 0.8; s.bz[i] = dz * r0
                s.dist[i] = min(r0 / radius, 1)
                s.haze[i] = 0
                s.spin[i] = 0.7
            } else {
                // Thin smooth disc (uniform angle, no arms).
                let d = pow(Gal.rand(), 0.5)
                let ang = Gal.rand(0, 2 * .pi)
                let r0 = d * radius
                s.bx[i] = cos(ang) * r0
                s.bz[i] = sin(ang) * r0
                s.by[i] = Gal.rand(-0.1, 0.1) * (1 + d)
                s.dist[i] = d
                s.haze[i] = Gal.rand() < 0.4 ? 1 : 0
                s.spin[i] = 1.4 - d
            }
        }
    }
}
```

- [ ] **Step 2: Register at index 5.** — `swift build`.
- [ ] **Step 3: Verify** — `SOUNDIS_THEME=5 … CAPTURE=$SS/lent.png`. Expected: a **smooth disc** (no spiral arms) with a **bright round bulge** at centre.
- [ ] **Step 4: Commit** — `git commit -m "soundis: add LENTICULAR galaxy morphology"`

---

## Task 7: Controls model — theme list, isGalaxy, density for all galaxies

**Files:**
- Modify: `Sources/Soundis/StageView.swift`
- Modify: `Sources/Soundis/ControlsView.swift`
- Modify: `Sources/Soundis/App.swift`

**Interfaces:**
- Consumes `Theme.isGalaxy` (Task 1), `StageView.themes`, `StageView.currentIndex`.
- Produces on `ControlsModel`: `@Published var isGalaxy: Bool`, `@Published var pickerOpen: Bool`, `@Published var themeList: [(name: String, isGalaxy: Bool)]`, `@Published var currentIndex: Int`, `var onSelectTheme: (Int) -> Void`.
- Produces `StageView.currentThemeIsGalaxy: Bool` and `StageView.themeList: [(String, Bool)]`.

- [ ] **Step 1: Expose theme info on StageView**

Add to `StageView` (near `setDensity`):
```swift
var currentThemeIsGalaxy: Bool { themes[currentIndex].isGalaxy }
var themeList: [(name: String, isGalaxy: Bool)] { themes.map { ($0.name, $0.isGalaxy) } }
```

- [ ] **Step 2: Extend ControlsModel**

In `ControlsView.swift`, add to `ControlsModel`:
```swift
    @Published var isGalaxy = true
    @Published var pickerOpen = false
    @Published var themeList: [(name: String, isGalaxy: Bool)] = []
    @Published var currentIndex = 0
    var onSelectTheme: (Int) -> Void = { _ in }
```

- [ ] **Step 3: Show density slider for any galaxy (not just "VORTEX")**

In `ControlsView.body`, replace the condition `if model.themeName == "VORTEX" {` with `if model.isGalaxy {`.

- [ ] **Step 4: Make the theme name a button that opens the picker**

In `ControlsView.body`, replace the theme-name `Text(model.themeName)…glassEffect()` block with:
```swift
                        Button { model.pickerOpen = true } label: {
                            Text(model.themeName)
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                                .frame(minWidth: 92)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                        }
                        .buttonStyle(.glass)
```

- [ ] **Step 5: Wire AppDelegate state on theme change + selection callback**

In `App.swift` `applicationDidFinishLaunching`, after `stage = StageView(audio: audio)` and before `stage.start()`, set the list + callback:
```swift
        controls.themeList = stage.themeList
        controls.onSelectTheme = { [weak self] i in self?.stage.setTheme(i); self?.controls.pickerOpen = false }
```
Replace the existing `stage.onThemeChange = { … }` body with:
```swift
        stage.onThemeChange = { [weak self] theme, index in
            guard let self else { return }
            self.controls.themeName = theme.name
            self.controls.isGalaxy = self.stage.currentThemeIsGalaxy
            self.controls.currentIndex = index
            self.applyPalette(theme.palette)
        }
```

- [ ] **Step 6: Build + verify density visibility**

`swift build` → clean. Then run the app bundle isn't required; instead verify logic by capture is not applicable (UI). Manual: `swift run` (or launch current bundle after Task 9). Confirm the density slider shows on galaxy themes (1–6) and disappears on WARP/SEISMO/RAIN/INVADERS (7–10) when cycling with ◀▶.

- [ ] **Step 7: Commit** — `git commit -m "soundis: controls expose theme list + isGalaxy; density for all galaxies"`

---

## Task 8: ThemePickerView (Liquid Glass card grid)

**Files:**
- Create: `Sources/Soundis/ThemePickerView.swift`
- Modify: `Sources/Soundis/ControlsView.swift` (present the picker as an overlay)
- Modify: `Sources/Soundis/App.swift` (Esc closes picker)

**Interfaces:** Consumes `ControlsModel` (`themeList`, `currentIndex`, `pickerOpen`, `onSelectTheme`, `accent`). Produces `struct ThemePickerView: View` and `struct GalaxyIcon: View`.

- [ ] **Step 1: Create `ThemePickerView.swift`**

```swift
import SwiftUI

/// Static card-grid theme picker overlay (Liquid Glass). Galaxy cards draw a
/// small static shape hint; other themes use an SF Symbol.
struct ThemePickerView: View {
    @ObservedObject var model: ControlsModel

    private let cols = [GridItem(.adaptive(minimum: 108), spacing: 14)]
    private let symbols: [String: String] = [
        "WARP": "tornado", "SEISMO": "waveform.path", "RAIN": "cloud.rain", "INVADERS": "gamecontroller"
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { model.pickerOpen = false }
            VStack(spacing: 14) {
                Text("SELECT THEME").font(.system(.headline, design: .monospaced))
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(Array(model.themeList.enumerated()), id: \.offset) { idx, t in
                        Button { model.onSelectTheme(idx) } label: {
                            VStack(spacing: 8) {
                                if t.isGalaxy {
                                    GalaxyIcon(id: t.name).frame(width: 54, height: 54)
                                } else {
                                    Image(systemName: symbols[t.name] ?? "circle")
                                        .font(.system(size: 26)).frame(width: 54, height: 54)
                                }
                                Text(t.name).font(.system(.caption, design: .monospaced))
                            }
                            .frame(width: 100, height: 92)
                            .padding(6)
                        }
                        .buttonStyle(idx == model.currentIndex ? AnyButtonStyle(.glassProminent) : AnyButtonStyle(.glass))
                    }
                }
                .padding(4)
            }
            .padding(24)
            .glassEffect(in: .rect(cornerRadius: 24))
            .frame(maxWidth: 560)
        }
        .tint(model.accent)
    }
}

/// Type-erased button style so the selected card can be prominent.
struct AnyButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView
    init(_ glass: GlassButtonStyle) { make = { AnyView(glass.makeBody(configuration: $0)) } }
    init(_ glass: GlassProminentButtonStyle) { make = { AnyView(glass.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// Tiny static shape hint per galaxy morphology, drawn once with Canvas.
struct GalaxyIcon: View {
    let id: String
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let R = min(size.width, size.height) * 0.44
            func dot(_ x: Double, _ y: Double, _ r: Double, _ o: Double) {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x + x - r, y: c.y + y - r, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(o)))
            }
            switch id {
            case "SPIRAL", "BARRED":
                let arms = id == "BARRED" ? 2 : 3
                for a in 0..<arms {
                    let base = Double(a) / Double(arms) * 2 * .pi
                    for k in 0..<26 {
                        let d = Double(k) / 26
                        let ang = base + d * 4.2
                        let rr = (id == "BARRED" ? Double(R) * (0.3 + d * 0.7) : Double(R) * d)
                        dot(cos(ang) * rr, sin(ang) * rr, 1.4, 0.9 - d * 0.5)
                    }
                }
            case "ELLIPTICAL":
                for _ in 0..<70 {
                    let r = pow(Double.random(in: 0...1), 0.7) * Double(R)
                    let a = Double.random(in: 0...(2 * .pi))
                    dot(cos(a) * r, sin(a) * r * 0.6, 1.3, 0.85 - r / Double(R) * 0.5)
                }
            case "IRREGULAR":
                for _ in 0..<60 {
                    dot(Double.random(in: -Double(R)...Double(R)), Double.random(in: -Double(R) * 0.7...Double(R) * 0.7), 1.3, 0.8)
                }
            case "RING":
                for k in 0..<48 {
                    let a = Double(k) / 48 * 2 * .pi
                    dot(cos(a) * Double(R) * 0.8, sin(a) * Double(R) * 0.8, 1.5, 0.9)
                }
            default: // LENTICULAR
                for k in 0..<40 {
                    let a = Double(k) / 40 * 2 * .pi
                    dot(cos(a) * Double(R), sin(a) * Double(R) * 0.35, 1.3, 0.8)
                }
                for _ in 0..<20 { let r = Double.random(in: 0...Double(R) * 0.35); let a = Double.random(in: 0...(2 * .pi)); dot(cos(a) * r, sin(a) * r, 1.4, 0.95) }
            }
        }
    }
}
```

- [ ] **Step 2: Present the picker over the controls**

In `ControlsView.body`, wrap the outermost content so the picker overlays when open. Change the final modifiers of the top-level `VStack(spacing: 0) { … }` to add:
```swift
        .overlay { if model.pickerOpen { ThemePickerView(model: model) } }
```
(place `.overlay` before `.frame(maxWidth: .infinity, maxHeight: .infinity)`).

- [ ] **Step 3: Esc closes the picker**

In `App.swift` `handleKey`, add before the digit check:
```swift
        if event.keyCode == 53 { // Esc
            if controls.pickerOpen { controls.pickerOpen = false; return true }
            return false
        }
```

- [ ] **Step 4: Build**

`swift build 2>&1 | grep -E 'error:|Build complete'` → `Build complete!`. If `AnyButtonStyle` init overloads are ambiguous, split into two named static factories `AnyButtonStyle.glass` / `.glassProminent` returning `AnyButtonStyle` and use those.

- [ ] **Step 5: Verify (live)**

`./Scripts/make-app.sh && open build/Soundis.app`. Click the theme name → picker opens with a 10-card grid (6 galaxy shape-icons + 4 SF Symbols), current theme prominent. Click a galaxy card → applies + closes. Click outside / Esc → closes.

- [ ] **Step 6: Commit** — `git commit -m "soundis: add Liquid Glass theme picker (card grid)"`

---

## Task 9: Finalize registry, full smoke, signed bundle

**Files:** Modify `Sources/Soundis/Theme.swift` (confirm final order); no code beyond ordering.

- [ ] **Step 1: Confirm `makeThemes()` final order**

```swift
static func makeThemes() -> [Theme] {
    [
        GalaxyTheme(SpiralMorphology()), GalaxyTheme(BarredMorphology()),
        GalaxyTheme(EllipticalMorphology()), GalaxyTheme(IrregularMorphology()),
        GalaxyTheme(RingMorphology()), GalaxyTheme(LenticularMorphology()),
        WarpTheme(), SeismoTheme(), RainTheme(), InvadersTheme(),
    ]
}
```

- [ ] **Step 2: Capture all six galaxies for a final visual check**

```bash
SS=$(mktemp -d)
for i in 0 1 2 3 4 5; do SOUNDIS_THEME=$i SOUNDIS_DENSITY=0.6 SOUNDIS_CAPTURE="$SS/g$i.png" .build/debug/Soundis; done
open "$SS"/g*.png
```
Expected: six visually distinct galaxies (spiral, barred, ellipsoid blob, clumps, ring, disc+bulge).

- [ ] **Step 3: Signed bundle + live smoke**

```bash
./Scripts/make-app.sh && open build/Soundis.app
```
Cycle 1–9 + ◀▶ through all 10 themes; open picker and pick each galaxy; drag density on a galaxy (packs/thins); confirm density slider hidden on non-galaxy themes. Confirm the window title-bar drag still works and the picker doesn't move the window.

- [ ] **Step 4: Commit** — `git commit -m "soundis: finalize 10-theme registry (6 galaxies + 4)"`

---

## Self-Review

**Spec coverage:**
- 6 morphologies as separate themes → Tasks 1–6 + registry Task 9. ✓
- Shared GalaxyTheme (projection/audio/colour/camera/density/core) → Task 1. ✓
- Static card-grid picker, open via theme-name, close on card/outside/Esc → Task 8. ✓
- Density slider for all galaxies (flag not name) → Task 7 Step 3. ✓
- 10-theme roster, galaxies first → Task 9. ✓
- Per-morphology accent for UI tint → each morphology's `accentHex`; palette in Task 1 init. ✓
- Offscreen-capture verification → every galaxy task's verify step. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code; verify steps give exact commands + expected shape. ✓

**Type consistency:** `Morphology.generate(into:count:)`, `GalaxyStars` field names (`bx,by,bz,dist,spin,phase,speed,haze`), `GalaxyTheme(_:)`, `Theme.isGalaxy`, `ControlsModel` fields (`isGalaxy,pickerOpen,themeList,currentIndex,onSelectTheme`), `StageView.themeList/currentThemeIsGalaxy` are used identically across tasks. ✓

**Risk note:** `AnyButtonStyle` wrapping `GlassButtonStyle`/`GlassProminentButtonStyle` is the one uncertain API; Task 8 Step 4 gives the fallback (named factories) if the initializer overloads are ambiguous.
