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
