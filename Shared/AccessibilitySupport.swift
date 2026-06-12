import SwiftUI

enum AccessibilityStatusTone {
    case success
    case warning
    case error
    case information
    case neutral

    var iconName: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        case .information:
            return "info.circle.fill"
        case .neutral:
            return "circle.fill"
        }
    }
}

@MainActor
enum AccessibilitySupport {
    static func update(
        reduceMotion: Bool,
        animation: Animation? = .easeInOut(duration: 0.2),
        _ changes: () -> Void
    ) {
        if reduceMotion {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, changes)
        } else {
            withAnimation(animation, changes)
        }
    }
}

private struct ReduceMotionTransactionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transaction { transaction in
            if reduceMotion {
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
        }
    }
}

private struct AccessibilityTextPairModifier: ViewModifier {
    let label: String
    let value: String

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
            .accessibilityValue(Text(value))
    }
}

extension View {
    func reduceMotionSensitive() -> some View {
        modifier(ReduceMotionTransactionModifier())
    }

    func accessibilityTextPair(label: String, value: String) -> some View {
        modifier(AccessibilityTextPairModifier(label: label, value: value))
    }
}
