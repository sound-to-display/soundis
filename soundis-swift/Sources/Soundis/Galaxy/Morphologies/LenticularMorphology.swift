import Foundation

/// Smooth armless disc with a bright spherical central bulge.
struct LenticularMorphology: Morphology {
    let id = "lenticular", name = "LENTICULAR", accentHex = "#d6d9e6"
    private let radius = 4.0

    func generate(into s: inout GalaxyStars, count: Int) {
        for i in 0..<count {
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
