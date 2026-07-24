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

/// Floating Liquid Glass chrome (macOS 26): a status pill up top and a glass
/// control capsule at the bottom, layered over the visualizer.
struct ControlsView: View {
    @ObservedObject var model: ControlsModel

    var body: some View {
        VStack(spacing: 0) {
            Text(model.status)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .glassEffect()
                .padding(.top, 18)

            Spacer()

            VStack(spacing: 10) {
                // Galaxy-only: star density (high = more + smaller, low = sparser).
                if model.isGalaxy {
                    HStack(spacing: 10) {
                        Image(systemName: "circle.grid.2x2").font(.caption)
                        Slider(value: $model.density, in: 0...1)
                            .frame(width: 140)
                            .onChange(of: model.density) { _, v in model.onDensity(v) }
                        Image(systemName: "circle.hexagongrid.fill").font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassEffect()
                }

                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        source("MIC", key: "mic", action: model.onMic)
                        source("SYSTEM", key: "system", action: model.onSystem)

                        Button(action: model.onPrev) {
                            Image(systemName: "chevron.left").fontWeight(.semibold)
                        }
                        .buttonStyle(.glass)

                        Button { model.pickerOpen = true } label: {
                            Text(model.themeName)
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                                .frame(minWidth: 92)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                        }
                        .buttonStyle(.glass)

                        Button(action: model.onNext) {
                            Image(systemName: "chevron.right").fontWeight(.semibold)
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .padding(.bottom, 26)
        }
        .tint(model.accent)
        .overlay { if model.pickerOpen { ThemePickerView(model: model) } }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    /// A source toggle (MIC / SYSTEM): prominent glass when it's the live source.
    @ViewBuilder
    private func source(_ title: String, key: String, action: @escaping () -> Void) -> some View {
        let label = Text(title).font(.system(.body, design: .monospaced).weight(.medium))
        if model.activeSource == key {
            Button(action: action) { label }.buttonStyle(.glassProminent)
        } else {
            Button(action: action) { label }.buttonStyle(.glass)
        }
    }
}
