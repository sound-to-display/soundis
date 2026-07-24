import SwiftUI

/// Static card-grid theme picker overlay (Liquid Glass). Galaxy cards draw a
/// small static shape hint; other themes use an SF Symbol.
struct ThemePickerView: View {
    @ObservedObject var model: ControlsModel

    private let cols = [GridItem(.adaptive(minimum: 108), spacing: 14)]
    private let symbols: [String: String] = [
        "WARP": "tornado", "SEISMO": "waveform.path", "RAIN": "cloud.rain", "INVADERS": "gamecontroller"
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture { model.pickerOpen = false }
            VStack(spacing: 14) {
                Text("SELECT THEME").font(.system(.headline, design: .monospaced))
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(Array(model.themeList.enumerated()), id: \.offset) { idx, t in
                        Button { model.onSelectTheme(idx) } label: {
                            VStack(spacing: 8) {
                                if t.isGalaxy {
                                    GalaxyIcon(id: t.name).frame(width: 54, height: 54)
                                } else {
                                    Image(systemName: symbols[t.name] ?? "circle")
                                        .font(.system(size: 26)).frame(width: 54, height: 54)
                                }
                                Text(t.name).font(.system(.caption, design: .monospaced))
                            }
                            .frame(width: 100, height: 92)
                            .padding(6)
                        }
                        .buttonStyle(idx == model.currentIndex ? AnyButtonStyle(.glassProminent) : AnyButtonStyle(.glass))
                    }
                }
                .padding(4)
            }
            .padding(24)
            .glassEffect(in: .rect(cornerRadius: 24))
            .frame(maxWidth: 560)
        }
        .tint(model.accent)
    }
}

/// Type-erased button style so the selected card can be prominent.
struct AnyButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView
    init(_ glass: GlassButtonStyle) { make = { AnyView(glass.makeBody(configuration: $0)) } }
    init(_ glass: GlassProminentButtonStyle) { make = { AnyView(glass.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

/// Tiny static shape hint per galaxy morphology, drawn once with Canvas.
struct GalaxyIcon: View {
    let id: String
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let R = min(size.width, size.height) * 0.44
            func dot(_ x: Double, _ y: Double, _ r: Double, _ o: Double) {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x + x - r, y: c.y + y - r, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(o)))
            }
            switch id {
            case "SPIRAL", "BARRED":
                let arms = id == "BARRED" ? 2 : 3
                for a in 0..<arms {
                    let base = Double(a) / Double(arms) * 2 * .pi
                    for k in 0..<26 {
                        let d = Double(k) / 26
                        let ang = base + d * 4.2
                        let rr = (id == "BARRED" ? Double(R) * (0.3 + d * 0.7) : Double(R) * d)
                        dot(cos(ang) * rr, sin(ang) * rr, 1.4, 0.9 - d * 0.5)
                    }
                }
            case "ELLIPTICAL":
                for _ in 0..<70 {
                    let r = pow(Double.random(in: 0...1), 0.7) * Double(R)
                    let a = Double.random(in: 0...(2 * .pi))
                    dot(cos(a) * r, sin(a) * r * 0.6, 1.3, 0.85 - r / Double(R) * 0.5)
                }
            case "IRREGULAR":
                for _ in 0..<60 {
                    dot(Double.random(in: -Double(R)...Double(R)), Double.random(in: -Double(R) * 0.7...Double(R) * 0.7), 1.3, 0.8)
                }
            case "RING":
                for k in 0..<48 {
                    let a = Double(k) / 48 * 2 * .pi
                    dot(cos(a) * Double(R) * 0.8, sin(a) * Double(R) * 0.8, 1.5, 0.9)
                }
            default: // LENTICULAR
                for k in 0..<40 {
                    let a = Double(k) / 40 * 2 * .pi
                    dot(cos(a) * Double(R), sin(a) * Double(R) * 0.35, 1.3, 0.8)
                }
                for _ in 0..<20 { let r = Double.random(in: 0...Double(R) * 0.35); let a = Double.random(in: 0...(2 * .pi)); dot(cos(a) * r, sin(a) * r, 1.4, 0.95) }
            }
        }
    }
}
