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

    /// Bounds-check-free view of every attribute for the render hot loop.
    struct Buffers {
        let bx, by, bz, dist, spin, phase, speed, haze: UnsafeBufferPointer<Double>
    }

    /// Vends `UnsafeBufferPointer`s for all attribute arrays in one call so the
    /// draw loop avoids per-element bounds checks without deep closure nesting.
    func withBuffers<R>(_ body: (Buffers) -> R) -> R {
        bx.withUnsafeBufferPointer { bxp in by.withUnsafeBufferPointer { byp in
        bz.withUnsafeBufferPointer { bzp in dist.withUnsafeBufferPointer { dp in
        spin.withUnsafeBufferPointer { snp in phase.withUnsafeBufferPointer { php in
        speed.withUnsafeBufferPointer { spp in haze.withUnsafeBufferPointer { hzp in
            body(Buffers(bx: bxp, by: byp, bz: bzp, dist: dp,
                         spin: snp, phase: php, speed: spp, haze: hzp))
        } } } } } } } }
    }
}
