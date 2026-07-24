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
}
