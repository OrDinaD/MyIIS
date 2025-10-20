import Foundation

protocol DormitoryServicing {
    func fetchDormitoryInfo() async throws -> DormitoryInfo
    func fetchResidenceHistory() async throws -> [ResidenceHistory]
    func availableActions(for info: DormitoryInfo) -> [DormitoryAction]
}

enum DormitoryServiceError: Error, LocalizedError {
    case unauthorized
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Не удалось загрузить данные. Авторизуйтесь повторно."
        case .serviceUnavailable: return "Сервис общежития временно недоступен."
        }
    }
}

final class DormitoryService: DormitoryServicing {

    private let delay: UInt64

    init(simulatedDelay: UInt64 = 350_000_000) {
        self.delay = simulatedDelay
    }

    func fetchDormitoryInfo() async throws -> DormitoryInfo {
        try await Task.sleep(nanoseconds: delay)
        return DormitoryInfo.previewValue
    }

    func fetchResidenceHistory() async throws -> [ResidenceHistory] {
        try await Task.sleep(nanoseconds: delay / 2)
        return ResidenceHistory.preview
    }

    func availableActions(for info: DormitoryInfo) -> [DormitoryAction] {
        var actions: [DormitoryAction] = []

        if info.status != .expelled {
            actions.append(DormitoryAction(type: .makePayment))
        }

        if info.status == .debt || (info.daysUntilContractEnds() ?? Int.max) <= 45 {
            actions.append(DormitoryAction(type: .extendContract))
        }

        if info.status != .expelled {
            actions.append(DormitoryAction(type: .submitMaintenance))
            actions.append(DormitoryAction(type: .requestRelocation))
        }

        return actions
    }
}

#if DEBUG
extension DormitoryService {
    static let preview = DormitoryService(simulatedDelay: 50_000_000)
}
#endif
