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
        }
    }
}
