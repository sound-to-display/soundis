import Foundation

/// A galaxy shape: fills every star's base position + attributes.
protocol Morphology {
    var id: String { get }
    var name: String { get }
    var accentHex: String { get }   // Liquid Glass UI tint only
    func generate(into s: inout GalaxyStars, count: Int)
}

/// Shared helpers for generators.
enum Gal {
    static func rand(_ lo: Double = 0, _ hi: Double = 1) -> Double { Double.random(in: lo...hi) }
    /// Approx. gaussian in [-1,1]-ish (sum of 3 uniforms).
    static func gauss() -> Double { (Double.random(in: -1...1) + Double.random(in: -1...1) + Double.random(in: -1...1)) / 1.7 }
    /// Uniform point direction on a unit sphere → (x,y,z).
    static func sphere() -> (Double, Double, Double) {
        let u = Double.random(in: -1...1), t = Double.random(in: 0...(2 * .pi)), s = (1 - u * u).squareRoot()
        return (s * cos(t), u, s * sin(t))
    }
}
