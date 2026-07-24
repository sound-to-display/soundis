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
