import AppKit
import AVFoundation
import Combine
import CoreGraphics
import SwiftUI

/// Swift port of the Electron shell (main.js + renderer.js): builds the window,
/// hosts the StageView, and overlays the SwiftUI Liquid Glass controls (MIC /
/// SYSTEM + theme selector), retinting the glass to each theme's accent.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var stage: StageView!
    private let audio = AudioSourceManager()
    private let controls = ControlsModel()
    private var keyMonitor: Any?
    private var pickerWindow: NSPanel?
    private var cancellables = Set<AnyCancellable>()

    private var activeSource: AudioSourceManager.Source?

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
        // Not movable-by-background: it would hijack drags on the controls
        // (the slider). The window still moves from the transparent title bar.
        window.isMovableByWindowBackground = false
        window.backgroundColor = NSColor(hex: "#0a0a0a")
        window.center()

        let content = NSView()
        content.wantsLayer = true

        stage = StageView(audio: audio)
        controls.themeList = stage.themeList
        controls.onSelectTheme = { [weak self] i in self?.stage.setTheme(i); self?.controls.pickerOpen = false }
        stage.onThemeChange = { [weak self] theme, index in
            guard let self else { return }
            self.controls.themeName = theme.name
            self.controls.isGalaxy = self.stage.currentThemeIsGalaxy
            self.controls.currentIndex = index
            self.applyPalette(theme.palette)
        }
        stage.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stage)

        controls.status = "READY — MIC 또는 SYSTEM을 선택하세요"
        controls.onMic = { [weak self] in self?.toggleMic() }
        controls.onSystem = { [weak self] in self?.toggleSystem() }
        controls.onPrev = { [weak self] in self?.stage.prev() }
        controls.onNext = { [weak self] in self?.stage.next() }
        controls.onDensity = { [weak self] d in self?.stage.setDensity(CGFloat(d)) }
        stage.setDensity(CGFloat(controls.density))

        // Drive a separate floating window from the picker-open state.
        controls.$pickerOpen
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] open in self?.setPickerVisible(open) }
            .store(in: &cancellables)

        let overlay = NSHostingView(rootView: ControlsView(model: controls))
        overlay.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(overlay)

        NSLayoutConstraint.activate([
            stage.topAnchor.constraint(equalTo: content.topAnchor),
            stage.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stage.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stage.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            overlay.topAnchor.constraint(equalTo: content.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: content.trailingAnchor),
        ])

        window.contentView = content
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            (self?.handleKey(event) ?? false) ? nil : event
        }

        let env = ProcessInfo.processInfo.environment
        if let t = env["SOUNDIS_THEME"], let i = Int(t) { stage.setInitialTheme(i) }
        if let ds = env["SOUNDIS_DENSITY"], let dv = Double(ds) {
            controls.density = dv
            stage.setDensity(CGFloat(dv))
        }
        stage.start()

        if env["SOUNDIS_AUTOSYSTEM"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.toggleSystem() }
        }

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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // The floating picker panel shouldn't keep the app (or block quit) alive.
        NSApp.windows.allSatisfy { $0 === pickerWindow || !$0.isVisible }
    }

    // MARK: - Theme picker window

    private func setPickerVisible(_ open: Bool) {
        if open { showPicker() } else { pickerWindow?.orderOut(nil) }
    }

    private func showPicker() {
        if pickerWindow == nil {
            let hosting = NSHostingController(rootView: ThemePickerView(model: controls))
            let panel = NSPanel(contentViewController: hosting)
            panel.title = "테마 선택"
            panel.styleMask = [.titled, .closable, .utilityWindow, .fullSizeContentView]
            panel.titlebarAppearsTransparent = true
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear
            panel.setContentSize(NSSize(width: 580, height: 460))
            panel.delegate = self
            panel.center()
            pickerWindow = panel
        }
        pickerWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Sync state when the user closes the panel via its own close button.
        if (notification.object as? NSWindow) === pickerWindow { controls.pickerOpen = false }
    }

    // MARK: - Audio sources

    private func toggleMic() {
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
                    self.refreshActiveSource()
                    self.setStatus("MIC ACTIVE")
                } catch {
                    self.setStatus("마이크 시작 실패: \(error.localizedDescription)")
                }
            }
        }
    }

    private func toggleSystem() {
        // ScreenCaptureKit (audio included) is gated by Screen Recording
        // permission, and the grant only takes effect after an app relaunch.
        // If it isn't already present, prompt + open Settings and bail with a
        // clear message instead of silently capturing nothing.
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
            setStatus("화면 기록 권한을 허용한 뒤 앱을 다시 실행하세요 (시스템 설정 › 개인정보 보호 및 보안 › 화면 기록).")
            return
        }
        setStatus("SYSTEM AUDIO 연결 중...")
        Task { @MainActor in
            do {
                try await audio.useSystemAudio()
                activeSource = .system
                refreshActiveSource()
                setStatus("SYSTEM AUDIO ACTIVE")
            } catch {
                FileHandle.standardError.write(Data("[soundis] useSystemAudio threw: \(error)\n".utf8))
                setStatus("시스템 오디오 캡처 실패: \(error.localizedDescription)")
            }
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        if event.keyCode == 53 { // Esc
            if controls.pickerOpen { controls.pickerOpen = false; return true }
            return false
        }
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

    // MARK: - State → controls

    private func applyPalette(_ palette: Palette) {
        window.backgroundColor = NSColor(hex: palette.bg)
        controls.accent = Color(nsColor: NSColor(hex: palette.accent))
    }

    private func refreshActiveSource() {
        switch activeSource {
        case .mic: controls.activeSource = "mic"
        case .system: controls.activeSource = "system"
        case nil: controls.activeSource = nil
        }
    }

    private func setStatus(_ text: String) { controls.status = text }
}
