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
        }
    }
}
