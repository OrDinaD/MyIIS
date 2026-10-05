import SwiftUI

/// Geometry-based observation also supports the app's iOS 17 deployment target.
struct ScheduleObservedScrollView<Content: View>: View {
    enum Threshold {
        case pastBottom(CGFloat)
        case pastTop(CGFloat)
        case pulledDown(CGFloat)
    }

    let threshold: Threshold
    let onCrossThreshold: () -> Void
    var onProgress: (CGFloat) -> Void = { _ in }
    @ViewBuilder let content: () -> Content
    @Namespace private var coordinateSpace
    @State private var crossed = false

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                content()
                    .background {
                        GeometryReader { geometry in
                            let frame = geometry.frame(in: .named(coordinateSpace))
                            Color.clear
                                .onChange(of: frame) { _, bounds in
                                    update(bounds: bounds, viewportHeight: viewport.size.height)
                                }
                        }
                    }
            }
            .coordinateSpace(name: coordinateSpace)
            .scrollBounceBehavior(.always)
        }
    }

    private func update(bounds: CGRect, viewportHeight: CGFloat) {
        let isPast: Bool
        switch threshold {
        case .pastBottom(let distance):
            isPast = bounds.minY < 0 && bounds.maxY < viewportHeight - distance
        case .pastTop(let distance):
            isPast = bounds.minY < -distance
        case .pulledDown(let distance):
            let progress = min(1, max(0, bounds.minY / max(1, distance)))
            onProgress(progress)
            isPast = progress >= 1
        }
        if isPast && !crossed { onCrossThreshold() }
        crossed = isPast
    }
}
