import AppKit
import QuartzCore

/// Owns the render loop (CVDisplayLink), theme lifecycle, frame assembly
/// and the 250ms dip-through transition — the Swift port of stage.js.
final class StageView: NSView {
    private let audio: AudioSourceManager
    let themes: [Theme]
    private(set) var currentIndex = 0
    private var transitioning = false

    var onThemeChange: ((Theme, Int) -> Void)?

    private var frame_ = Frame()
    private var displayLink: CVDisplayLink?
    private var lastTime: Double = 0
    private var startTime: Double = CACurrentMediaTime()

    // Dip-through overlay: 0 = clear, 1 = covered
    private var overlayAlpha: CGFloat = 0
    private var overlayTarget: CGFloat = 0
    private var overlayColor: RGB = RGB(0x0a0a0a)
    private var pendingIndex: Int?

    init(audio: AudioSourceManager) {
        self.audio = audio
        self.themes = ThemeRegistry.makeThemes()
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(hex: themes[0].palette.bg).cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    func start() {
        onThemeChange?(themes[currentIndex], currentIndex)
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        CVDisplayLinkSetOutputHandler(link) { [weak self] _, _, _, _, _ in
            DispatchQueue.main.async { self?.tick() }
            return kCVReturnSuccess
        }
        CVDisplayLinkStart(link)
        displayLink = link
    }

    func stop() {
        if let link = displayLink { CVDisplayLinkStop(link) }
        displayLink = nil
    }

    // MARK: - Theme switching (250ms dip out, swap, 250ms dip back)

    func setTheme(_ index: Int) {
        guard !transitioning, index != currentIndex, index >= 0, index < themes.count else { return }
        transitioning = true
        pendingIndex = index
        overlayColor = RGB(hexString: themes[index].palette.bg)
        overlayTarget = 1
    }

    func next() { setTheme((currentIndex + 1) % themes.count) }
    func prev() { setTheme((currentIndex - 1 + themes.count) % themes.count) }

    /// Choose the starting theme before `start()` (no transition). Ignored once running.
    func setInitialTheme(_ index: Int) {
        guard displayLink == nil, index >= 0, index < themes.count else { return }
        currentIndex = index
        layer?.backgroundColor = NSColor(hex: themes[index].palette.bg).cgColor
    }

    // MARK: - Render loop

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = lastTime == 0 ? 1.0 / 60.0 : min(now - lastTime, 0.1)
        lastTime = now

        // Advance the transition overlay (250ms each way)
        let speed = CGFloat(dt / 0.25)
        if overlayAlpha < overlayTarget {
            overlayAlpha = min(overlayAlpha + speed, 1)
            if overlayAlpha >= 1, let next = pendingIndex {
                themes[currentIndex].dispose()
                currentIndex = next
                pendingIndex = nil
                onThemeChange?(themes[currentIndex], currentIndex)
                overlayTarget = 0
            }
        } else if overlayAlpha > overlayTarget {
            overlayAlpha = max(overlayAlpha - speed, 0)
            if overlayAlpha <= 0 && transitioning && pendingIndex == nil {
                transitioning = false
            }
        }

        audio.fill(frame: &frame_)
        frame_.time = now - startTime
        frame_.dt = dt
        themes[currentIndex].update(frame: frame_)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        themes[currentIndex].draw(in: ctx, size: bounds.size)
        if overlayAlpha > 0 {
            ctx.setFillColor(overlayColor.cgColor(alpha: overlayAlpha))
            ctx.fill(bounds)
        }
    }
}

extension RGB {
    init(hexString: String) {
        var value: UInt64 = 0
        Scanner(string: String(hexString.dropFirst())).scanHexInt64(&value)
        self.init(UInt32(value))
    }
}
