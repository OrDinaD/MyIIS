import Foundation
import SwiftUI

struct DormitoryStatusTag: View {
    let status: String

    var tint: Color {
        switch DormitoryPresentationState(status: status) {
        case .settled:
            return .green
        case .readyToSettle:
            return .orange
        case .rejected:
            return .red
        case .evicted:
            return .gray
        case .waiting, .documentsAccepted, .unknown:
            return .blue
        }
    }

    var body: some View {
        Text(status)
            .font(.caption.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.2), tint.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
    }
}

enum DormitoryPresentationState: Equatable {
    case waiting
    case documentsAccepted
    case readyToSettle
    case settled
    case rejected
    case evicted
    case unknown

    init(status: String) {
        let normalized = status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if normalized.contains("высел") {
            self = .evicted
        } else if normalized.contains("к засел") || normalized.contains("готов") {
            self = .readyToSettle
        } else if normalized.contains("засел") {
            self = .settled
        } else if normalized.contains("отказ") || normalized.contains("отклон") {
            self = .rejected
        } else if normalized.contains("документ") && normalized.contains("принят") {
            self = .documentsAccepted
        } else if normalized.contains("ожидан") || normalized.contains("очеред") {
            self = .waiting
        } else {
            self = .unknown
        }
    }
}

struct DormitoryPlacement: Equatable {
    let room: String
    let dormitory: String?

    static func parse(_ source: String?) -> DormitoryPlacement? {
        guard let source else { return nil }

        let value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let components = value.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
        guard components.count == 2 else {
            return DormitoryPlacement(room: value, dormitory: nil)
        }

        let room = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let rawDormitory = String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDormitory = rawDormitory.lowercased()

        if normalizedDormitory.contains("аренд") || normalizedDormitory.contains("rental") {
            return DormitoryPlacement(
                room: room.isEmpty ? value : room,
                dormitory: rawDormitory
            )
        }

        let prefixPattern = #"(?i)^\s*(общежитие|общ(?:ежитие)?\.?|dormitory|гуртожиток|гуртовня)\s*№?\s*"#
        let cleanedDormitory = rawDormitory
            .replacingOccurrences(
                of: prefixPattern,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanedDormitory != rawDormitory, !cleanedDormitory.isEmpty else {
            return DormitoryPlacement(room: value, dormitory: nil)
        }

        return DormitoryPlacement(
            room: room.isEmpty ? value : room,
            dormitory: cleanedDormitory
        )
    }
}

func dormitoryLocalized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

extension DormitoryQueueApplication {
    var presentationState: DormitoryPresentationState {
        DormitoryPresentationState(status: status)
    }

    var placement: DormitoryPlacement? {
        DormitoryPlacement.parse(roomInfo)
    }

    var presentationDate: Date? {
        settledDate ?? acceptedDate ?? applicationDate
    }
}
