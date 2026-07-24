import SwiftUI

/// Observable bridge between the AppKit AppDelegate and the SwiftUI Liquid Glass
/// control overlay. The delegate writes state in; the closures call back out.
final class ControlsModel: ObservableObject {
    @Published var status = ""
    @Published var themeName = ""
    @Published var activeSource: String?      // "mic" | "system" | nil
    @Published var accent = Color.white

    var onMic: () -> Void = {}
    var onSystem: () -> Void = {}
    var onPrev: () -> Void = {}
    var onNext: () -> Void = {}
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

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    source("MIC", key: "mic", action: model.onMic)
                    source("SYSTEM", key: "system", action: model.onSystem)

                    Button(action: model.onPrev) {
                        Image(systemName: "chevron.left").fontWeight(.semibold)
                    }
                    .buttonStyle(.glass)

                    Text(model.themeName)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .frame(minWidth: 92)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .glassEffect()

                    Button(action: model.onNext) {
                        Image(systemName: "chevron.right").fontWeight(.semibold)
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(.bottom, 26)
        }
        .tint(model.accent)
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
