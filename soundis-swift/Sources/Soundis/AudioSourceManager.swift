import AVFoundation
import Accelerate
import ScreenCaptureKit

/// Captures mic or system audio, runs a 512-point FFT (Web-Audio-analyser-style)
/// and exposes band energies + waveform, matching the Electron app's analyser.
final class AudioSourceManager: NSObject {
    static let fftSize = 512
    static let binCount = 256 // fftSize / 2

    enum Source { case mic, system }
    private(set) var activeSource: Source?

    private let engine = AVAudioEngine()
    private var scStream: SCStream?
    private var sampleRate: Double = 48000

    // Latest time-domain window (mono), written by capture threads.
    private let lock = NSLock()
    private var ring = [Float](repeating: 0, count: fftSize)

    // FFT state
    private var fftSetup: FFTSetup?
    private let log2n = vDSP_Length(9) // log2(512)
    private var window = [Float](repeating: 0, count: fftSize)
    private var smoothed = [Float](repeating: 0, count: binCount)
    private var realp = [Float](repeating: 0, count: binCount)
    private var imagp = [Float](repeating: 0, count: binCount)
    private var windowed = [Float](repeating: 0, count: fftSize)
    private var magnitudes = [Float](repeating: 0, count: binCount)

    // Outputs (read on render thread via fill(frame:))
    private var bins = [Float](repeating: 0, count: binCount)
    private var waveformOut = [Float](repeating: 0, count: fftSize)

    private let smoothing: Float = 0.8
    private let minDb: Float = -100
    private let maxDb: Float = -30

    override init() {
        super.init()
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        vDSP_blkman_window(&window, vDSP_Length(Self.fftSize), 0)
    }

    deinit {
        if let setup = fftSetup { vDSP_destroy_fftsetup(setup) }
    }

    // MARK: - Sources

    func useMicrophone() throws {
        try stopCurrent()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        sampleRate = format.sampleRate
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.ingest(buffer: buffer)
        }
        engine.prepare()
        try engine.start()
        activeSource = .mic
    }

    func useSystemAudio() async throws {
        try stopCurrent()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw NSError(domain: "Soundis", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 1
        // Minimal video output (required by SCStream); we ignore the frames.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 5)

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "soundis.audio"))
        try await stream.startCapture()
        scStream = stream
        sampleRate = 48000
        activeSource = .system
    }

    private func stopCurrent() throws {
        if engine.isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        if let stream = scStream {
            let semaphore = DispatchSemaphore(value: 0)
            stream.stopCapture { _ in semaphore.signal() }
            semaphore.wait()
            scStream = nil
        }
        activeSource = nil
    }

    // MARK: - Ingest

    private func ingest(buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        ingest(samples: data, count: Int(buffer.frameLength))
    }

    private func ingest(samples: UnsafePointer<Float>, count: Int) {
        lock.lock()
        defer { lock.unlock() }
        if count >= Self.fftSize {
            ring.withUnsafeMutableBufferPointer { dst in
                dst.baseAddress!.update(from: samples + (count - Self.fftSize), count: Self.fftSize)
            }
        } else {
            // Shift left, append new samples
            let keep = Self.fftSize - count
            ring.withUnsafeMutableBufferPointer { dst in
                let base = dst.baseAddress!
                base.update(from: base + count, count: keep)
                (base + keep).update(from: samples, count: count)
            }
        }
    }

    // MARK: - Analysis (called from render thread)

    /// Fills the frame's bins/waveform/band values from the latest window.
    func fill(frame: inout Frame) {
        lock.lock()
        for i in 0..<Self.fftSize { waveformOut[i] = ring[i] }
        lock.unlock()

        frame.waveform = waveformOut

        guard let setup = fftSetup else { return }

        vDSP_vmul(waveformOut, 1, window, 1, &windowed, 1, vDSP_Length(Self.fftSize))
        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { src in
                    src.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: Self.binCount) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(Self.binCount))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(Self.binCount))
            }
        }
        var scale: Float = 1.0 / Float(Self.fftSize)
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(Self.binCount))

        // Web Audio analyser behavior: smooth magnitudes, then byte-scale in dB.
        for i in 0..<Self.binCount {
            smoothed[i] = smoothing * smoothed[i] + (1 - smoothing) * magnitudes[i]
            let db = 20 * log10(max(smoothed[i], 1e-12))
            let normalized = (db - minDb) / (maxDb - minDb)
            bins[i] = min(max(normalized, 0), 1)
        }
        frame.bins = bins

        // Band split (matches Electron app: bass <250Hz, mid <4kHz, treble <16kHz)
        let hzPerBin = Float(sampleRate) / Float(Self.fftSize)
        frame.bass = average(upTo: 250, from: 20, hzPerBin: hzPerBin)
        frame.mid = average(upTo: 4000, from: 250, hzPerBin: hzPerBin)
        frame.treble = average(upTo: 16000, from: 4000, hzPerBin: hzPerBin)
        frame.level = (frame.bass + frame.mid + frame.treble) / 3
    }

    private func average(upTo highHz: Float, from lowHz: Float, hzPerBin: Float) -> Float {
        let lo = max(Int(lowHz / hzPerBin), 0)
        let hi = min(Int(highHz / hzPerBin), Self.binCount - 1)
        guard hi > lo else { return 0 }
        var sum: Float = 0
        for i in lo...hi { sum += bins[i] }
        return sum / Float(hi - lo + 1)
    }
}

extension AudioSourceManager: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else { return }
        var abl = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &abl,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr, let mData = abl.mBuffers.mData else { return }
        let count = Int(abl.mBuffers.mDataByteSize) / MemoryLayout<Float>.size
        let samples = mData.bindMemory(to: Float.self, capacity: count)
        ingest(samples: samples, count: count)
    }
}
