import Combine
import Foundation

@MainActor
final class DiplomaApplicationViewModel: ObservableObject {
    @Published private(set) var personalInformation: DiplomaPersonalInformation?
    @Published private(set) var applications: [DiplomaApplication] = []
    @Published private(set) var supervisors: [DiplomaSupervisor] = []
    @Published private(set) var employeeTopics: [DiplomaEmployeeTopic] = []
    @Published private(set) var downloadedApplicationURL: URL?
    @Published private(set) var isLoading = false
    @Published private(set) var isSearching = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var isDownloading = false
    @Published private(set) var isShowingStaleDataWarning = false
    @Published private(set) var lastUpdateTime: Date?
    @Published private(set) var staleErrorMessage: String?
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var supervisorQuery = ""
    @Published var selectedSupervisor: DiplomaSupervisor?
    @Published var selectedTopic: DiplomaEmployeeTopic?
    @Published var topicName = ""
    @Published var localizedTopicName = ""
    @Published var justification = ""

    private let service: DiplomaApplicationServicing
    private let userDefaults: UserDefaults
    private var hasLoadedOnce = false
    private var lastSearchQuery = ""

    private static let cacheKey = "DiplomaApplicationViewModel.contextCache"

    private struct CachedSnapshot: Codable {
        let context: DiplomaContext
        let updatedAt: Date
    }

    init(service: DiplomaApplicationServicing? = nil, userDefaults: UserDefaults = .standard) {
        self.service = service ?? DiplomaApplicationService()
        self.userDefaults = userDefaults
        _ = applyCachedSnapshotIfAvailable(markStale: false, message: nil)
    }

    var screenTitle: String {
        isFirstDegree ? "Дипломный проект" : "Диссертация"
    }

    var isFirstDegree: Bool {
        personalInformation?.degree == 1
    }

    var isBelarusian: Bool {
        personalInformation?.belarusian == true
    }

    var statusMessage: String {
        guard let personalInformation else {
            return "Загружаем данные из ИИС."
        }
        guard personalInformation.graduating else {
            return "Оставить заявку Вы сможете только на выпускном курсе."
        }
        if hasAcceptedApplication {
            return "У Вас уже есть одобренная заявка."
        }
        if hasProcessingApplication {
            return "У Вас уже есть обрабатывающаяся заявка."
        }
        return "Выберите руководителя и тему диплома."
    }

    var canOpenRequestForm: Bool {
        !isLoading && !isSubmitting && !hasAcceptedApplication && !hasProcessingApplication
    }

    var hasContent: Bool {
        personalInformation != nil || !applications.isEmpty
    }

    var canSubmitApplication: Bool {
        guard selectedSupervisor != nil, !isSubmitting else {
            return false
        }

        if selectedTopic == nil && topicName.trimmed.isEmpty {
            return false
        }

        if selectedTopic == nil && !topicName.trimmed.isEmpty && justification.trimmed.isEmpty {
            return false
        }

        return true
    }

    var localizedTopicPlaceholder: String {
        isBelarusian ? "Увядзіце тэму на беларускай мове" : "Enter topic in English"
    }

    func loadIfNeeded() async {
        guard !hasLoadedOnce else { return }
        await reload()
    }

    func reload() async {
        if isLoading { return }
        if !hasContent {
            _ = applyCachedSnapshotIfAvailable(markStale: false, message: nil)
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let context = try await service.fetchContext()
            apply(context: context, updatedAt: Date())
            persist(context: context)
            hasLoadedOnce = true
            isShowingStaleDataWarning = false
            staleErrorMessage = nil
            errorMessage = nil
        } catch {
            let message = displayMessage(for: error)
            if applyCachedSnapshotIfAvailable(markStale: true, message: message) {
                errorMessage = nil
            } else {
                errorMessage = message
            }
        }
    }

    func searchSupervisors() async {
        let query = supervisorQuery.trimmed
        guard query.count >= 2 else {
            supervisors = []
            lastSearchQuery = ""
            return
        }
        guard query != lastSearchQuery else {
            return
        }

        lastSearchQuery = query
        isSearching = true
        defer { isSearching = false }

        do {
            supervisors = try await service.searchSupervisors(query: query, includeExternal: isFirstDegree)
            errorMessage = nil
        } catch {
            supervisors = []
            errorMessage = displayMessage(for: error)
        }
    }

    func selectSupervisor(_ supervisor: DiplomaSupervisor) async {
        selectedSupervisor = supervisor
        selectedTopic = nil
        employeeTopics = []

        guard let employeeId = supervisor.employeeId else {
            return
        }

        do {
            employeeTopics = try await service.fetchEmployeeTopics(employeeId: employeeId)
            errorMessage = nil
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func selectTopic(_ topic: DiplomaEmployeeTopic?) {
        selectedTopic = topic
        if topic != nil {
            topicName = ""
        }
    }

    func submitApplication() async -> Bool {
        guard canSubmitApplication, let selectedSupervisor else {
            errorMessage = "Выберите руководителя и заполните обязательные поля."
            return false
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let payload = DiplomaApplicationPayload(
            employeeId: selectedSupervisor.employeeId,
            externalManagerId: selectedSupervisor.externalManagerId,
            topicName: selectedTopic?.topic ?? topicName.trimmed,
            englishTopic: isBelarusian ? nil : localizedTopicName.trimmed.nilIfEmpty,
            belarusianTopic: isBelarusian ? localizedTopicName.trimmed.nilIfEmpty : nil,
            justification: justification.trimmed.nilIfEmpty
        )

        do {
            let application = try await service.submitApplication(payload)
            applications.insert(application, at: 0)
            clearForm()
            successMessage = "Заявка успешно отправлена."
            errorMessage = nil
            await reload()
            return true
        } catch {
            errorMessage = displayMessage(for: error)
            return false
        }
    }

    func deleteApplication(_ application: DiplomaApplication) async {
        do {
            try await service.deleteApplication(id: application.id)
            applications.removeAll { $0.id == application.id }
            successMessage = "Заявка отменена."
            errorMessage = nil
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func downloadApplication(_ application: DiplomaApplication) async {
        isDownloading = true
        defer { isDownloading = false }

        do {
            downloadedApplicationURL = try await service.downloadApplication(for: application)
            successMessage = "Заявление сформировано."
            errorMessage = nil
        } catch {
            errorMessage = displayMessage(for: error)
        }
    }

    func clearDownloadedApplication() {
        downloadedApplicationURL = nil
    }

    private var hasAcceptedApplication: Bool {
        applications.contains { [1, 2].contains($0.statusId) }
    }

    private var hasProcessingApplication: Bool {
        applications.contains { $0.statusId == 5 }
    }

    private func persist(context: DiplomaContext) {
        let snapshot = CachedSnapshot(context: context, updatedAt: Date())
        guard let payload = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(payload, forKey: Self.cacheKey)
    }

    private func applyCachedSnapshotIfAvailable(markStale: Bool, message: String?) -> Bool {
        guard let payload = userDefaults.data(forKey: Self.cacheKey),
              let snapshot = try? JSONDecoder().decode(CachedSnapshot.self, from: payload) else {
            return false
        }

        apply(context: snapshot.context, updatedAt: snapshot.updatedAt)
        if markStale {
            hasLoadedOnce = true
        }
        isShowingStaleDataWarning = markStale
        staleErrorMessage = markStale ? message : nil
        return true
    }

    private func apply(context: DiplomaContext, updatedAt: Date) {
        personalInformation = context.personalInformation
        applications = context.applications
        lastUpdateTime = updatedAt
    }

    private func clearForm() {
        supervisorQuery = ""
        selectedSupervisor = nil
        supervisors = []
        employeeTopics = []
        selectedTopic = nil
        topicName = ""
        localizedTopicName = ""
        justification = ""
    }

    private func displayMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
