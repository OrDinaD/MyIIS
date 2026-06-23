import SwiftUI

// MARK: - Supporting Views

struct LiquidBackground: View {
    var body: some View {
        LinearGradient(
            colors: Color.gradientBackground,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.20))
                    .blur(radius: 40)
                    .frame(width: 220, height: 220)
                    .offset(x: 140, y: -120)

                Circle()
                    .fill(Color.white.opacity(0.12))
                    .blur(radius: 60)
                    .frame(width: 260, height: 260)
                    .offset(x: -100, y: 40)
            }
            .allowsHitTesting(false)
        }
        .zIndex(0)
        .accessibilityHidden(true)
    }
}

struct GlassCapsuleStyle: ButtonStyle {
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(tint)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.7),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.white.opacity(0.30))
                    .blur(radius: 8)
                    .frame(width: 22, height: 22)
                    .offset(x: 6, y: 4)
            }
            .shadow(
                color: tint.opacity(configuration.isPressed ? 0.15 : 0.25),
                radius: configuration.isPressed ? 2 : 6,
                y: 3
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct QuickActionButton: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(LinearGradient.iconGradient(color))

                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 112 : 90)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient.glassOverlay)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LinearGradient.glassBorder, lineWidth: 1.5)
                    }
                    .shadow(color: color.opacity(0.12), radius: 12, x: 0, y: 6)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, alignment: .center)
            Text(title)
                .font(.headline)
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // Верхний блик для Liquid Glass эффекта - адаптивный
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient.glassOverlay)
                    }
                    .overlay {
                        // Граница с адаптивным градиентом
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LinearGradient.glassBorder, lineWidth: 1.5)
                    }
                    .cardShadow()
            }
    }
}

struct InfoRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let label: String
    let value: String

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    labelText
                    valueText
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    labelText
                    Spacer(minLength: 12)
                    valueText
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .accessibilityTextPair(label: label, value: value)
    }

    private var labelText: some View {
        Text(label)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private var valueText: some View {
        Text(value)
            .font(.body)
            .fontWeight(.medium)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingRow: View {
    let icon: String
    let label: String
    let isEnabled: Bool

    private var stateText: String {
        isEnabled
            ? NSLocalizedString("common_enabled", comment: "")
            : NSLocalizedString("common_disabled", comment: "")
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(isEnabled ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)
            Text(label)
                .font(.body)
            Spacer()
            Label(stateText, systemImage: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .labelStyle(.iconOnly)
                .foregroundStyle(isEnabled ? Color.statusSuccess : Color.statusError.opacity(0.8))
        }
        .accessibilityTextPair(label: label, value: stateText)
    }
}

// MARK: - FlowLayout for Skills

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = AuthenticationService.shared
        authService.currentUser = User.mock

        return ProfileView()
            .environmentObject(authService)
    }
}
#endif
