import Combine
import Foundation

@MainActor
final class DiplomaViewModel: ObservableObject {

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var progress: DiplomaProgress?

    private let diplomaService: DiplomaServicing
    private let logService = LogService.shared
    private var currentUserIdentifier: String?
    private let isPreview: Bool

    init(diplomaService: DiplomaServicing? = nil, isPreview: Bool = false) {
        self.diplomaService = diplomaService ?? DiplomaService()
        self.isPreview = isPreview

        if isPreview {
            progress = .preview
        }
    }

    var hasContent: Bool {
        progress != nil
    }

    var milestones: [Milestone] {
        progress?.sortedMilestones() ?? []
    }

    var completionPercentage: Double {
        progress?.completionPercentage ?? 0
    }

    var completionText: String {
        progress?.completionPercentText ?? "0%"
    }

    var statusText: String {
        progress?.status.displayName ?? ""
    }

    var topic: String {
        progress?.topic ?? ""
    }

    var advisorText: String? {
        progress?.advisor
    }

    var commentText: String? {
        guard let text = progress?.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }

    var updatedAtText: String? {
        guard let date = progress?.updatedAt else { return nil }
        return "Обновлено " + Self.dateFormatter.string(from: date)
    }

    var nextMilestone: Milestone? {
        progress?.nextMilestone
    }

    func plannedDateText(for milestone: Milestone) -> String? {
        guard let date = milestone.plannedDate else { return nil }
        return Self.dateFormatter.string(from: date)
    }

    func actualDateText(for milestone: Milestone) -> String? {
        guard let date = milestone.actualDate else { return nil }
        return Self.dateFormatter.string(from: date)
    }

    func loadProgress(for userIdentifier: String?) async {
        await performLoad(for: userIdentifier, force: false)
    }

    func refresh(for userIdentifier: String?) async {
        await performLoad(for: userIdentifier, force: true)
    }

    private func performLoad(for userIdentifier: String?, force: Bool) async {
        guard !isPreview else { return }

        guard let userIdentifier, !userIdentifier.isEmpty else {
            errorMessage = "Не удалось определить пользователя"
            return
        }

        if !force, currentUserIdentifier == userIdentifier, progress != nil {
            return
        }

        isLoading = true
        errorMessage = nil
        logService.log("Loading diploma progress for user: \(userIdentifier)")

        do {
            let result = try await diplomaService.fetchDiplomaProgress(for: userIdentifier)
            currentUserIdentifier = userIdentifier
            progress = result
            logService.log("✅ Diploma progress loaded: milestones = \(result.milestones.count)")
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
            logService.log("❌ Diploma API error: \(apiError.localizedDescription)")
        } catch {
            errorMessage = error.localizedDescription
            logService.log("❌ Diploma unexpected error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter
    }()
}

#if DEBUG
extension DiplomaViewModel {
    static var preview: DiplomaViewModel {
        DiplomaViewModel(diplomaService: DiplomaService.preview, isPreview: true)
    }
}
#endif
