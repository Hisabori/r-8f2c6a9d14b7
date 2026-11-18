import SwiftUI
@MainActor final class NativeStartupGate: ObservableObject {
    @Published private(set) var finished = false
    private var claimed = false
    func claim() -> Bool { guard !claimed, !finished else { return false }; claimed = true; return true }
    func finish() { finished = true }
}
struct NativeStartupReveal: ViewModifier {
    @ObservedObject var gate: NativeStartupGate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    @State private var appeared = false
    func body(content: Content) -> some View {
        content.overlay {
            if !gate.finished && !reduceMotion {
                ZStack {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                    VStack(spacing: 20) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 28).fill(Color.teal.opacity(0.12))
                            Circle().fill(Color.teal).padding(17)
                            Image(systemName: "waveform.path.ecg").font(.system(size: 38, weight: .medium)).foregroundStyle(.white)
                        }.frame(width: 112, height: 112)
                        Text("OnCare").font(.largeTitle.bold())
                        Text("나의 하루와 리서치").font(.subheadline).foregroundStyle(.secondary)
                    }.opacity(appeared ? 1 : 0).scaleEffect(appeared ? 1 : 0.96)
                }
                .contentShape(Rectangle()).onTapGesture { gate.finish() }
                .accessibilityElement(children: .ignore).accessibilityLabel("OnCare 시작")
                .accessibilityAddTraits(.isButton).accessibilityHint("두 번 탭하여 바로 시작")
                .accessibilityAction { gate.finish() }.transition(.opacity)
            }
        }.task {
            guard gate.claim() else { return }
            guard !reduceMotion else { gate.finish(); return }
            withAnimation(.easeOut(duration: 0.36)) { appeared = true }
            do { try await Task.sleep(nanoseconds: 520_000_000) } catch { gate.finish(); return }
            guard !Task.isCancelled else { gate.finish(); return }
            withAnimation(.easeOut(duration: 0.16)) { gate.finish() }
        }
        .onChange(of: reduceMotion) { if $0 { gate.finish() } }
        .onChange(of: phase) { if $0 == .background { gate.finish() } }
        .onDisappear { gate.finish() }
    }
}
