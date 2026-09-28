import SwiftUI

struct NotificationFocusHighlight: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.orange.opacity(isVisible ? 0.95 : 0), lineWidth: 3)
                    .padding(2)
                    .allowsHitTesting(false)
            }
            .shadow(color: .orange.opacity(isVisible ? 0.24 : 0), radius: 12)
    }
}

extension View {
    func notificationFocusHighlight(_ isVisible: Bool) -> some View {
        modifier(NotificationFocusHighlight(isVisible: isVisible))
    }
}
