import SwiftUI

/// Observable bridge between the AppKit AppDelegate and the SwiftUI Liquid Glass
/// control overlay. The delegate writes state in; the closures call back out.
final class ControlsModel: ObservableObject {
    @Published var status = ""
    @Published var themeName = ""
    @Published var activeSource: String?      // "mic" | "system" | nil
    @Published var accent = Color.white
    @Published var density = 0.5              // galaxy star density (0…1)
    @Published var isGalaxy = true
    @Published var pickerOpen = false
    @Published var themeList: [(name: String, isGalaxy: Bool)] = []
    @Published var currentIndex = 0
    var onSelectTheme: (Int) -> Void = { _ in }

    var onMic: () -> Void = {}
    var onSystem: () -> Void = {}
    var onPrev: () -> Void = {}
    var onNext: () -> Void = {}
    var onDensity: (Double) -> Void = { _ in }
}

/// Floating Liquid Glass chrome (macOS 26): a bottom control bar of clear,
/// interactive glass pills that the galaxy shows through.
struct ControlsView: View {
    @ObservedObject var model: ControlsModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            GlassEffectContainer(spacing: 12) {
                VStack(spacing: 9) {
                    // Galaxy-only: star density (high = more + smaller, low = sparser).
                    if model.isGalaxy {
                        HStack(spacing: 10) {
                            Image(systemName: "circle.grid.2x2").font(.footnote)
                            Slider(value: $model.density, in: 0...1)
                                .frame(width: 150)
                                .onChange(of: model.density) { _, v in model.onDensity(v) }
                            Image(systemName: "circle.hexagongrid.fill").font(.footnote)
                        }
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .glassEffect(.clear.tint(model.accent.opacity(0.18)).interactive(), in: .capsule)
                    }

                    HStack(spacing: 8) {
                        source("MIC", key: "mic", action: model.onMic)
                        source("SYSTEM", key: "system", action: model.onSystem)
                        icon("chevron.left", action: model.onPrev)
                        Button { model.pickerOpen = true } label: {
                            pill(Text(model.themeName)
                                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                .frame(minWidth: 80))
                        }
                        .buttonStyle(.plain)
                        icon("chevron.right", action: model.onNext)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .tint(model.accent)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    /// A source toggle (MIC / SYSTEM): faint accent tint on the glass when live.
    @ViewBuilder
    private func source(_ title: String, key: String, action: @escaping () -> Void) -> some View {
        let active = model.activeSource == key
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .glassEffect(active ? .clear.tint(model.accent.opacity(0.55)).interactive()
                                    : .clear.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private func icon(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pill(Image(systemName: name).font(.subheadline.weight(.semibold)))
        }
        .buttonStyle(.plain)
    }

    private func pill(_ content: some View) -> some View {
        content
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .glassEffect(.clear.interactive(), in: .capsule)
    }
}
