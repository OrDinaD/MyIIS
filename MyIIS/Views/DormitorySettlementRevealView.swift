import SwiftUI
import UIKit

struct DormitorySettlementRevealView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let reveal: DormitorySettlementReveal
    let onDismiss: () -> Void

    @State private var presentationTrigger = 0
    @State private var stage = Stage.arriving
    @State private var isDormitoryRevealed = false
    @State private var isRoomRevealed = false
    @State private var isReturning = false

    private enum Stage {
        case arriving
        case scratching
        case completed
    }

    private var placement: DormitoryPlacement {
        reveal.application.placement ?? DormitoryPlacement(
            room: reveal.application.roomInfo ?? dormitoryLocalized("dormitory_place_unknown"),
            dormitory: nil
        )
    }

    private var completionTrigger: Int {
        (isDormitoryRevealed ? 1 : 0) + (isRoomRevealed ? 2 : 0)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .opacity(isReturning ? 0 : 0.76)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    Text(dormitoryLocalized("dormitory_reveal_congratulations"))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(stage == .arriving ? 0 : 1)
                        .offset(y: stage == .arriving ? 12 : 0)

                    animatedCard(
                        width: min(max(proxy.size.width - 32, 300), 430)
                    )

                    Text(helperText)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(maxWidth: 340)
                        .opacity(stage == .arriving ? 0 : 1)
                }
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if stage == .completed && !reduceMotion {
                    DormitoryConfettiView(isActive: !isReturning)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isModal)
        .sensoryFeedback(.impact(weight: .heavy), trigger: isRoomRevealed)
        .task {
            await beginPresentation()
        }
        .task(id: completionTrigger) {
            guard completionTrigger == 3 else { return }
            stage = .completed
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }

            withAnimation(reduceMotion ? nil : .spring(duration: 0.58, bounce: 0.16)) {
                isReturning = true
            }
            try? await Task.sleep(for: reduceMotion ? .milliseconds(80) : .milliseconds(560))
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }

    private var helperText: String {
        switch stage {
        case .arriving:
            return ""
        case .scratching:
            return isDormitoryRevealed
                ? dormitoryLocalized("dormitory_reveal_room_hint")
                : dormitoryLocalized("dormitory_reveal_dormitory_hint")
        case .completed:
            return dormitoryLocalized("dormitory_reveal_complete")
        }
    }

    private func animatedCard(width: CGFloat) -> some View {
        let shouldReduceMotion = reduceMotion
        return KeyframeAnimator(
            initialValue: shouldReduceMotion ? SettlementRevealAnimationValues.revealed : .initial,
            trigger: presentationTrigger
        ) { values in
            DormitorySettlementFlipCard(
                reveal: reveal,
                placement: placement,
                rotation: values.rotation,
                scratchEnabled: stage != .arriving,
                isDormitoryRevealed: $isDormitoryRevealed,
                isRoomRevealed: $isRoomRevealed
            )
            .frame(width: width)
            .scaleEffect(values.scale)
            .offset(y: values.verticalOffset)
            .rotation3DEffect(
                .degrees(values.rotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.42
            )
            .keyframeAnimator(initialValue: 0.0, trigger: isDormitoryRevealed) { content, offset in
                content.offset(y: shouldReduceMotion ? 0 : offset)
            } keyframes: { _ in
                SpringKeyframe(-12, duration: 0.18)
                SpringKeyframe(0, duration: 0.34)
            }
            .scaleEffect(isReturning ? 0.66 : 1)
            .offset(y: isReturning ? -240 : 0)
            .opacity(isReturning ? 0 : 1)
        } keyframes: { _ in
            KeyframeTrack(\.rotation) {
                CubicKeyframe(540, duration: 0.72)
                CubicKeyframe(900, duration: 0.78)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.07, duration: 1.14)
                SpringKeyframe(1, duration: 0.36)
            }
            KeyframeTrack(\.verticalOffset) {
                CubicKeyframe(-10, duration: 1.12)
                SpringKeyframe(0, duration: 0.38)
            }
        }
        .animation(shouldReduceMotion ? nil : .spring(duration: 0.58, bounce: 0.16), value: isReturning)
    }

    private func beginPresentation() async {
        if reduceMotion {
            stage = .scratching
            return
        }

        try? await Task.sleep(for: .milliseconds(140))
        guard !Task.isCancelled else { return }
        presentationTrigger += 1

        try? await Task.sleep(for: .milliseconds(1_500))
        guard !Task.isCancelled else { return }
        withAnimation(.snappy(duration: 0.34)) {
            stage = .scratching
        }
    }
}

private struct SettlementRevealAnimationValues: Animatable {
    var rotation: Double
    var scale: Double
    var verticalOffset: Double

    static let initial = SettlementRevealAnimationValues(
        rotation: 0,
        scale: 0.78,
        verticalOffset: 96
    )

    static let revealed = SettlementRevealAnimationValues(
        rotation: 180,
        scale: 1,
        verticalOffset: 0
    )

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get {
            AnimatablePair(rotation, AnimatablePair(scale, verticalOffset))
        }
        set {
            rotation = newValue.first
            scale = newValue.second.first
            verticalOffset = newValue.second.second
        }
    }
}

private struct DormitorySettlementFlipCard: View {
    let reveal: DormitorySettlementReveal
    let placement: DormitoryPlacement
    let rotation: Double
    let scratchEnabled: Bool
    @Binding var isDormitoryRevealed: Bool
    @Binding var isRoomRevealed: Bool

    private var isShowingBack: Bool {
        let normalized = (rotation.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        return normalized > 90 && normalized < 270
    }

    var body: some View {
        ZStack {
            documentsAcceptedFace
                .opacity(isShowingBack ? 0 : 1)

            settlementFace
                .rotation3DEffect(
                    .degrees(180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.42
                )
                .opacity(isShowingBack ? 1 : 0)
        }
        .frame(height: 470)
        .shadow(color: .black.opacity(0.32), radius: 30, y: 18)
        .accessibilityElement(children: .contain)
    }

    private var documentsAcceptedFace: some View {
        revealFaceBackground(
            colors: [
                Color(red: 0.04, green: 0.29, blue: 0.88),
                Color(red: 0.04, green: 0.47, blue: 0.96),
                Color(red: 0.12, green: 0.64, blue: 0.98)
            ]
        ) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 42, weight: .bold))
                    .symbolRenderingMode(.hierarchical)

                Spacer()

                Text(DormitoryApplicationStatus.documentsAccepted.rawValue)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    String(
                        format: dormitoryLocalized("dormitory_application_number"),
                        reveal.application.number
                    )
                )
                .font(.headline)
                .foregroundStyle(.white.opacity(0.76))
            }
        }
    }

    private var settlementFace: some View {
        revealFaceBackground(
            colors: [
                Color(red: 0.02, green: 0.45, blue: 0.36),
                Color(red: 0.02, green: 0.62, blue: 0.46),
                Color(red: 0.04, green: 0.72, blue: 0.61)
            ]
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "house.fill")
                        .font(.title2.weight(.bold))
                        .frame(width: 46, height: 46)
                        .background(.white.opacity(0.16), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(reveal.application.status)
                            .font(.system(.title2, design: .rounded, weight: .bold))

                        Text(dormitoryLocalized("dormitory_reveal_subtitle"))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.78))
                    }

                    Spacer(minLength: 0)
                }

                ScratchRevealField(
                    title: dormitoryLocalized("dormitory_label_dormitory"),
                    value: placement.dormitory ?? dormitoryLocalized("dormitory_place_unknown"),
                    isEnabled: scratchEnabled,
                    lockedHint: dormitoryLocalized("dormitory_reveal_wait_hint"),
                    isRevealed: $isDormitoryRevealed
                )

                ScratchRevealField(
                    title: dormitoryLocalized("dormitory_label_room"),
                    value: placement.room,
                    isEnabled: scratchEnabled && isDormitoryRevealed,
                    lockedHint: dormitoryLocalized("dormitory_reveal_locked_room"),
                    isRevealed: $isRoomRevealed
                )

                HStack {
                    Label(
                        String(
                            format: dormitoryLocalized("dormitory_application_number"),
                            reveal.application.number
                        ),
                        systemImage: "number"
                    )

                    Spacer()

                    if isDormitoryRevealed && isRoomRevealed {
                        Label(
                            dormitoryLocalized("dormitory_reveal_complete_short"),
                            systemImage: "checkmark.circle.fill"
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))
            }
        }
    }

    private func revealFaceBackground<Content: View>(
        colors: [Color],
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 4)
                .offset(x: 130, y: -190)

            content()
                .foregroundStyle(.white)
                .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        }
    }
}

private struct ScratchRevealField: View {
    let title: String
    let value: String
    let isEnabled: Bool
    let lockedHint: String
    @Binding var isRevealed: Bool

    @State private var strokes: [[CGPoint]] = []
    @State private var activeStrokeIndex: Int?
    @State private var scratchedDistance = 0.0

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 7) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.66))

                Text(verbatim: value)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(.white)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.white.opacity(0.13))
            .accessibilityHidden(!isRevealed)

            if !isRevealed {
                scratchSurface

                if !isEnabled {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Color(uiColor: .systemGray3))

                    Label(lockedHint, systemImage: "lock.fill")
                        .font(.caption.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary.opacity(0.76))
                        .padding(.horizontal, 20)
                }
            }
        }
        .frame(height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(.white.opacity(0.17), lineWidth: 1)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isRevealed)
        .animation(.snappy(duration: 0.28), value: isEnabled)
        .animation(.snappy(duration: 0.28), value: isRevealed)
        .accessibilityElement(children: .contain)
    }

    private var scratchSurface: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(uiColor: .systemGray3),
                                Color(uiColor: .systemGray5),
                                Color(uiColor: .systemGray2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                HStack(spacing: 8) {
                    Image(systemName: "hand.draw.fill")
                    Text(dormitoryLocalized("dormitory_reveal_scratch"))
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary.opacity(0.76))

                Canvas { context, _ in
                    context.blendMode = .destinationOut
                    for stroke in strokes where !stroke.isEmpty {
                        var path = Path()
                        path.move(to: stroke[0])
                        for point in stroke.dropFirst() {
                            path.addLine(to: point)
                        }
                        context.stroke(
                            path,
                            with: .color(.white),
                            style: StrokeStyle(
                                lineWidth: 34,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }
                }
            }
            .compositingGroup()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        appendScratchPoint(value.location, in: proxy.size)
                    }
                    .onEnded { _ in
                        activeStrokeIndex = nil
                    },
                including: isEnabled ? .all : .none
            )
            .accessibilityLabel(isEnabled ? dormitoryLocalized("dormitory_reveal_scratch") : lockedHint)
            .accessibilityAddTraits(isEnabled ? .isButton : [])
            .accessibilityAction {
                guard isEnabled else { return }
                revealField()
            }
        }
    }

    private func appendScratchPoint(_ rawPoint: CGPoint, in size: CGSize) {
        guard isEnabled, !isRevealed, size.width > 0 else { return }

        let point = CGPoint(
            x: min(max(rawPoint.x, 0), size.width),
            y: min(max(rawPoint.y, 0), size.height)
        )

        if let activeStrokeIndex,
           let previousPoint = strokes[activeStrokeIndex].last {
            let segment = hypot(point.x - previousPoint.x, point.y - previousPoint.y)
            guard segment >= 1.5 else { return }
            strokes[activeStrokeIndex].append(point)
            scratchedDistance += segment
        } else {
            strokes.append([point])
            activeStrokeIndex = strokes.indices.last
        }

        if scratchedDistance >= max(150, size.width * 1.45) {
            revealField()
        }
    }

    private func revealField() {
        guard !isRevealed else { return }
        withAnimation(.snappy(duration: 0.3)) {
            isRevealed = true
        }
    }
}

#if DEBUG
#Preview("Раскрытие заселения") {
    DormitorySettlementRevealView(
        reveal: .demo,
        onDismiss: {}
    )
}

#Preview("Стираемые поля") {
    DormitorySettlementFlipCardPreview()
}

private struct DormitorySettlementFlipCardPreview: View {
    @State private var isDormitoryRevealed = false
    @State private var isRoomRevealed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.76)
                .ignoresSafeArea()

            DormitorySettlementFlipCard(
                reveal: .demo,
                placement: DormitoryPlacement(room: "1302-а", dormitory: "4"),
                rotation: 180,
                scratchEnabled: true,
                isDormitoryRevealed: $isDormitoryRevealed,
                isRoomRevealed: $isRoomRevealed
            )
            .frame(width: 360)
            .rotation3DEffect(
                .degrees(180),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.42
            )
        }
    }
}
#endif
