import Foundation

/// A flattened central lens girdled by a second ring of stars orbiting in a
/// perpendicular (polar) plane — the two structures visibly cross in 3-D.
struct PolarRingMorphology: Morphology {
    let id = "polarring", name = "POLAR RING", accentHex = "#7ad0ff"
    private let discR = 2.4, ringR = 3.6

    func generate(into s: inout GalaxyStars, count: Int) {
        for i in 0..<count {
            if Gal.rand() < 0.5 {
                // Central lens: flattened rotating disc in the x–z plane.
                let d = pow(Gal.rand(), 0.6)
                let ang = Gal.rand(0, 2 * .pi)
                let r = d * discR
                s.bx[i] = cos(ang) * r
                s.bz[i] = sin(ang) * r
                s.by[i] = Gal.rand(-0.12, 0.12) * (1 + d)
                s.dist[i] = min(d, 1)
                s.haze[i] = Gal.rand() < 0.3 ? 1 : 0
                s.spin[i] = 1.3 - d * 0.5
            } else {
                // Polar ring: circles in the y–z plane, perpendicular to the lens.
                let ang = Gal.rand(0, 2 * .pi)
                let r = ringR + Gal.gauss() * 0.4
                s.bx[i] = Gal.rand(-0.18, 0.18)       // thin in x
                s.by[i] = cos(ang) * r
                s.bz[i] = sin(ang) * r
                s.dist[i] = min(r / (ringR + 0.4), 1)
                s.haze[i] = 0
                s.spin[i] = 0                          // keep its polar orientation
            }
        }
    }
}
