import Foundation

@MainActor
final class DormitoryViewModel: ObservableObject {

    @Published private(set) var dormitoryInfo: DormitoryInfo?
    @Published private(set) var history: [ResidenceHistory]
    @Published private(set) var actions: [DormitoryAction]
    @Published var isLoading: Bool
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let dormitoryService: DormitoryServicing
    private var hasLoadedOnce: Bool

    init(dormitoryService: DormitoryServicing = DormitoryService(),
         initialInfo: DormitoryInfo? = nil,
         initialHistory: [ResidenceHistory] = [],
         initialActions: [DormitoryAction]? = nil) {
        self.dormitoryService = dormitoryService
        self.dormitoryInfo = initialInfo
        self.history = initialHistory
        self.actions = initialActions ?? []
        self.isLoading = false
        self.errorMessage = nil
        self.infoMessage = nil
        self.hasLoadedOnce = initialInfo != nil

        if let info = initialInfo, initialActions == nil {
            self.actions = dormitoryService.availableActions(for: info)
        }
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await loadData()
    }

    func reload() async {
        await loadData(force: true)
    }

    func triggerAction(_ action: DormitoryAction) {
        switch action.type {
        case .makePayment:
            infoMessage = "Перейдите в раздел оплат, чтобы завершить платёж."
        case .extendContract:
            infoMessage = "Вы можете продлить договор через деканат или онлайн-заявку."
        case .submitMaintenance:
            infoMessage = "Заявка отправлена в техническую службу."
        case .requestRelocation:
            infoMessage = "Переселение доступно после согласования с комендантом."
        }
    }

    func dismissInfoMessage() {
        infoMessage = nil
    }

    private func loadData(force: Bool = false) async {
        if !force && isLoading { return }
        isLoading = true
        errorMessage = nil

        do {
            let info = try await dormitoryService.fetchDormitoryInfo()
            let history = try await dormitoryService.fetchResidenceHistory()
            dormitoryInfo = info
            self.history = history.sorted(by: { $0.eventDate > $1.eventDate })
            actions = dormitoryService.availableActions(for: info)
            hasLoadedOnce = true
        } catch {
            if let error = error as? LocalizedError, let message = error.errorDescription {
                errorMessage = message
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}

#if DEBUG
extension DormitoryViewModel {
    static var preview: DormitoryViewModel {
        DormitoryViewModel(dormitoryService: DormitoryService.preview,
                           initialInfo: DormitoryInfo.previewValue,
                           initialHistory: ResidenceHistory.preview,
                           initialActions: DormitoryAction.preview)
    }
}
#endif
