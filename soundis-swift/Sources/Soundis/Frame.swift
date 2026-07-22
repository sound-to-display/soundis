import Foundation

/// Mirrors the JS frame contract: single struct reused every frame.
/// bass/mid/treble/level normalized 0-1; bins 256 values 0-1 (byte-equivalent /255);
/// waveform 512 samples centered at 0 (-1..1); time/dt in seconds.
struct Frame {
    var bass: Float = 0
    var mid: Float = 0
    var treble: Float = 0
    var level: Float = 0
    var bins = [Float](repeating: 0, count: 256)
    var waveform = [Float](repeating: 0, count: 512)
    var time: Double = 0
    var dt: Double = 0
}

struct Palette {
    let bg: String
    let accent: String
    let dim: String
}
