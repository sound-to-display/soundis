import Foundation

/// Two interacting cores flung apart with long tidal tails and a debris bridge
/// (an Antennae-style colliding pair). Strongly asymmetric.
struct PeculiarMorphology: Morphology {
    let id = "peculiar", name = "PECULIAR", accentHex = "#ff7ab0"
    private let radius = 4.2
    private let cores = [(x: -1.3, z: 0.4), (x: 1.3, z: -0.4)]

    func generate(into s: inout GalaxyStars, count: Int) {
        for i in 0..<count {
            let ci = i % 2
            let core = cores[ci]
            let roll = Gal.rand()
            if roll < 0.45 {
                // Dense, roughly spherical core clump.
                let r0 = pow(Gal.rand(), 0.7) * 1.2
                let (dx, dy, dz) = Gal.sphere()
                s.bx[i] = core.x + dx * r0
                s.by[i] = dy * r0 * 0.7
                s.bz[i] = core.z + dz * r0
                s.dist[i] = min(r0 / 1.2 * 0.5, 1)
                s.haze[i] = 0
                s.spin[i] = 0.9
            } else if roll < 0.8 {
                // Tidal tail sweeping outward, curving away from the core.
                let d = pow(Gal.rand(), 0.6)          // 0…1 along the tail
                let dir = ci == 0 ? 1.0 : -1.0
                let ang = (ci == 0 ? 2.2 : 2.2 + .pi) + d * 1.6 * dir
                let r = 1.0 + d * (radius + 1.0)
                let scat = Gal.rand(-0.25, 0.25) * (0.3 + d)
                s.bx[i] = core.x + cos(ang) * r + cos(ang + .pi / 2) * scat
                s.bz[i] = core.z + sin(ang) * r + sin(ang + .pi / 2) * scat
                s.by[i] = Gal.rand(-0.15, 0.15) * (1 + d)
                s.dist[i] = min(0.4 + d * 0.6, 1)
                s.haze[i] = Gal.rand() < 0.4 ? 1 : 0
                s.spin[i] = 0.5
            } else {
                // Ragged debris bridge stretched between the two cores.
                let t = Gal.rand()
                s.bx[i] = cores[0].x + (cores[1].x - cores[0].x) * t + Gal.gauss() * 0.5
                s.bz[i] = cores[0].z + (cores[1].z - cores[0].z) * t + Gal.gauss() * 0.5
                s.by[i] = Gal.gauss() * 0.3
                s.dist[i] = 0.5
                s.haze[i] = 1
                s.spin[i] = 0.6
            }
        }
    }
}
