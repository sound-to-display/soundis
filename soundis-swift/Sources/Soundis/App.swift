import AppKit
import AVFoundation

/// Swift port of the Electron shell (main.js + renderer.js): builds the window,
/// hosts the StageView, wires the MIC / SYSTEM buttons and the theme selector,
/// and reskins the chrome to each theme's palette.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var stage: StageView!
    private let audio = AudioSourceManager()

    private var statusLabel: NSTextField!
    private var themeNameLabel: NSTextField!
    private var micButton: NSButton!
    private var systemButton: NSButton!
    private var prevButton: NSButton!
    private var nextButton: NSButton!
    private var divider: NSView!
    private var keyMonitor: Any?

    private var activeSource: AudioSourceManager.Source?
    private var accent = NSColor(hex: "#e0a458")
    private var dim = NSColor(hex: "#5a4a38")
    private var bg = NSColor(hex: "#0a0a0a")

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "soundis"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = bg
        window.center()

        let content = NSView()
        content.wantsLayer = true

        stage = StageView(audio: audio)
        stage.onThemeChange = { [weak self] theme, _ in
            self?.themeNameLabel.stringValue = theme.name
            self?.applyPalette(theme.palette)
        }
        stage.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stage)

        statusLabel = makeLabel("READY — MIC 또는 SYSTEM을 선택하세요", size: 12)
        content.addSubview(statusLabel)

        micButton = makeButton("MIC", action: #selector(toggleMic))
        systemButton = makeButton("SYSTEM", action: #selector(toggleSystem))
        prevButton = makeButton("◀", action: #selector(prevTheme))
        nextButton = makeButton("▶", action: #selector(nextTheme))
        themeNameLabel = makeLabel("", size: 13)
        themeNameLabel.alignment = .center

        divider = NSView()
        divider.wantsLayer = true
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        divider.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let controls = NSStackView(views: [micButton, systemButton, divider, prevButton, themeNameLabel, nextButton])
        controls.orientation = .horizontal
        controls.spacing = 10
        controls.alignment = .centerY
        controls.translatesAutoresizingMaskIntoConstraints = false
        themeNameLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
        content.addSubview(controls)

        NSLayoutConstraint.activate([
            stage.topAnchor.constraint(equalTo: content.topAnchor),
            stage.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stage.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stage.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            statusLabel.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 44),

            controls.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            controls.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -26),
        ])

        window.contentView = content
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            (self?.handleKey(event) ?? false) ? nil : event
        }

        let env = ProcessInfo.processInfo.environment
        if let t = env["SOUNDIS_THEME"], let i = Int(t) { stage.setInitialTheme(i) }
        stage.start()

        // Dev capture: render the stage to a PNG after it settles, then quit.
        if let path = env["SOUNDIS_CAPTURE"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
                guard let self, let rep = self.stage.bitmapImageRepForCachingDisplay(in: self.stage.bounds) else {
                    NSApp.terminate(nil); return
                }
                self.stage.cacheDisplay(in: self.stage.bounds, to: rep)
                if let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: URL(fileURLWithPath: path))
                }
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // MARK: - Audio sources

    @objc private func toggleMic() {
        setStatus("MIC 연결 중...")
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.setStatus("마이크 접근이 거부됐습니다. 시스템 설정에서 허용해주세요.")
                    return
                }
                do {
                    try self.audio.useMicrophone()
                    self.activeSource = .mic
                    self.updateButtons()
                    self.setStatus("MIC ACTIVE")
                } catch {
                    self.setStatus("마이크 시작 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func toggleSystem() {
        setStatus("SYSTEM AUDIO 연결 중...")
        Task { @MainActor in
            do {
                try await audio.useSystemAudio()
                activeSource = .system
                updateButtons()
                setStatus("SYSTEM AUDIO ACTIVE")
            } catch {
                setStatus("시스템 오디오 캡처 실패: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Theme switching

    @objc private func prevTheme() { stage.prev() }
    @objc private func nextTheme() { stage.next() }

    private func handleKey(_ event: NSEvent) -> Bool {
        if let ch = event.charactersIgnoringModifiers?.first,
           let n = ch.wholeNumberValue, n >= 1, n <= stage.themes.count {
            stage.setTheme(n - 1)
            return true
        }
        switch event.keyCode {
        case 123: stage.prev(); return true   // ←
        case 124: stage.next(); return true   // →
        default: return false
        }
    }

    // MARK: - Palette + chrome

    private func applyPalette(_ palette: Palette) {
        accent = NSColor(hex: palette.accent)
        dim = NSColor(hex: palette.dim)
        bg = NSColor(hex: palette.bg)
        window.backgroundColor = bg
        statusLabel.textColor = accent
        themeNameLabel.textColor = accent
        divider.layer?.backgroundColor = dim.cgColor
        updateButtons()
    }

    private func updateButtons() {
        style(micButton, active: activeSource == .mic)
        style(systemButton, active: activeSource == .system)
        style(prevButton, active: false)
        style(nextButton, active: false)
    }

    private func style(_ button: NSButton, active: Bool) {
        let fg = active ? bg : accent
        button.layer?.backgroundColor = active ? accent.cgColor : NSColor.clear.cgColor
        button.layer?.borderColor = (active ? accent : dim).cgColor
        button.attributedTitle = NSAttributedString(
            string: " \(button.title.trimmingCharacters(in: .whitespaces)) ",
            attributes: [
                .foregroundColor: fg,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            ]
        )
    }

    private func setStatus(_ text: String) { statusLabel.stringValue = text }

    // MARK: - Factories

    private func makeLabel(_ text: String, size: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.monospacedSystemFont(ofSize: size, weight: .medium)
        label.textColor = accent
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 4
        button.layer?.borderWidth = 1
        button.layer?.borderColor = dim.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        style(button, active: false)
        return button
    }
}
