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
                        .opacity(stage == .arriving || isReturning ? 0 : 1)
                        .offset(y: stage == .arriving ? 12 : 0)

                    animatedCard(
                        width: min(max(proxy.size.width - 32, 300), 430)
                    )

                    if stage == .scratching {
                        Text(scratchHelperText)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(maxWidth: 340)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
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
            withAnimation(.snappy(duration: 0.28)) {
                stage = .completed
            }
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, !isReturning else { return }
            await dismissCard()
        }
    }

    private var scratchHelperText: String {
        isDormitoryRevealed
            ? dormitoryLocalized("dormitory_reveal_room_hint")
            : dormitoryLocalized("dormitory_reveal_dormitory_hint")
    }

    private func animatedCard(width: CGFloat) -> some View {
        let shouldReduceMotion = reduceMotion
        return KeyframeAnimator(
            initialValue: shouldReduceMotion ? SettlementRevealAnimationValues.revealed : .initial,
            trigger: presentationTrigger
        ) { values in
            animatedCardContent(
                values: values,
                width: width,
                shouldReduceMotion: shouldReduceMotion
            )
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

    private func animatedCardContent(
        values: SettlementRevealAnimationValues,
        width: CGFloat,
        shouldReduceMotion: Bool
    ) -> some View {
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
    }

    private func dismissCard() async {
        guard !isReturning else { return }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.58, bounce: 0.16)) {
            isReturning = true
        }
        try? await Task.sleep(for: reduceMotion ? .milliseconds(80) : .milliseconds(560))
        guard !Task.isCancelled else { return }
        onDismiss()
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

                    Text(reveal.application.status)
                        .font(.system(.title2, design: .rounded, weight: .bold))

                    Spacer(minLength: 0)
                }

                DormitoryScratchRevealField(
                    title: dormitoryLocalized("dormitory_label_dormitory"),
                    value: placement.dormitory ?? dormitoryLocalized("dormitory_place_unknown"),
                    isEnabled: scratchEnabled,
                    lockedHint: dormitoryLocalized("dormitory_reveal_wait_hint"),
                    isRevealed: $isDormitoryRevealed
                )

                DormitoryScratchRevealField(
                    title: dormitoryLocalized("dormitory_label_room"),
                    value: placement.room,
                    isEnabled: scratchEnabled && isDormitoryRevealed,
                    lockedHint: dormitoryLocalized("dormitory_reveal_locked_room"),
                    isRevealed: $isRoomRevealed
                )

                Label(
                    String(
                        format: dormitoryLocalized("dormitory_application_number"),
                        reveal.application.number
                    ),
                    systemImage: "number"
                )
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
