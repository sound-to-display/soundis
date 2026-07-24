import Foundation

/// Central bar with two short arms curling off the bar tips, over a faint disc.
struct BarredMorphology: Morphology {
    let id = "barred", name = "BARRED", accentHex = "#6fa8ff"
    private let radius = 4.2, barLen = 1.9, twist = 2.2

    func generate(into s: inout GalaxyStars, count: Int) {
        for i in 0..<count {
            s.phase[i] = Gal.rand(0, 2 * .pi)
            s.speed[i] = 1.5 + Gal.rand(0, 4)
            let roll = Gal.rand()
            if roll < 0.34 {
                // Bar: elongated along x, thin in z; clamp so it ends at the arm start.
                let t = max(-1, min(Gal.gauss(), 1))   // -1…1 along the bar
                s.bx[i] = t * barLen
                s.bz[i] = Gal.rand(-0.3, 0.3)
                s.by[i] = Gal.rand(-0.15, 0.15)
                s.dist[i] = min(abs(t) * 0.4, 1)
                s.haze[i] = 0
                s.spin[i] = 1.15                        // rigid-body bar
            } else if roll < 0.82 {
                // Arm trailing from one of the two bar tips (angle 0 or π).
                let d = pow(Gal.rand(), 0.7)            // 0…1 along the arm
                let ang = (i % 2 == 0 ? 0.0 : .pi) + d * twist
                let r = barLen + d * (radius - barLen)
                let scat = Gal.rand(-0.28, 0.28) * (0.4 + d)
                s.bx[i] = cos(ang) * r + cos(ang + .pi / 2) * scat
                s.bz[i] = sin(ang) * r + sin(ang + .pi / 2) * scat
                s.by[i] = Gal.rand(-0.12, 0.12)
                s.dist[i] = min(0.4 + d * 0.6, 1)
                s.haze[i] = Gal.rand() < 0.25 ? 1 : 0
                s.spin[i] = 1.15 - d * 0.45             // arms trail the bar
            } else {
                // Faint diffuse disc filling the space between the arms.
                let d = pow(Gal.rand(), 0.5)
                let ang = Gal.rand(0, 2 * .pi)
                let r = d * radius
                s.bx[i] = cos(ang) * r
                s.bz[i] = sin(ang) * r
                s.by[i] = Gal.rand(-0.12, 0.12)
                s.dist[i] = min(0.3 + d * 0.7, 1)
                s.haze[i] = 1
                s.spin[i] = 1.15 - d * 0.45
            }
        }
    }
}
