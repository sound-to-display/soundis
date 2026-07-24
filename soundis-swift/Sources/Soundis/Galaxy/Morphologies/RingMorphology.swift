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
