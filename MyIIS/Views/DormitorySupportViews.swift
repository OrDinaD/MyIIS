import SwiftUI

struct DormitoryStatusTag: View {
    let status: String

    private var tint: Color {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("засел") {
            return .green
        }

        if normalized.contains("высел") {
            return .orange
        }

        if normalized.contains("отказ") || normalized.contains("отклон") {
            return .red
        }

        return .blue
    }

    var body: some View {
        Text(status)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
    }
}
