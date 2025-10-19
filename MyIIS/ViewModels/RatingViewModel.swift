import Combine
import Foundation

@MainActor
final class RatingViewModel: ObservableObject {

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var students: [StudentRating] = []
    @Published private(set) var checkpointNumbers: [Int] = []
    @Published private(set) var summary: RatingSummary?

    private let apiService: APIService
    private let logService = LogService.shared
    private var currentGroup: String?
    private let isPreview: Bool

    init(
        apiService: APIService = APIService(),
        isPreview: Bool = false
    ) {
        self.apiService = apiService
        self.isPreview = isPreview

        if isPreview {
            students = StudentRating.previewData
            checkpointNumbers = Self.makeCheckpointNumbers(from: students)
            summary = RatingSummary(students: students)
        }
    }

    func loadRating(forGroup group: String?) async {
        await loadRating(forGroup: group, force: false)
    }

    func refresh(forGroup group: String?) async {
        await loadRating(forGroup: group, force: true)
    }

    private func loadRating(forGroup group: String?, force: Bool) async {
        guard !isPreview else { return }

        guard let group = group, !group.isEmpty else {
            errorMessage = "Не удалось определить номер группы"
            return
        }

        if !force, currentGroup == group, !students.isEmpty { return }

        isLoading = true
        errorMessage = nil
        logService.log("Fetching rating for group: \(group)")

        do {
            let response = try await apiService.getRating(group: group)
            currentGroup = group
            students = response.sorted { lhs, rhs in
                (lhs.averageGrade ?? .zero) > (rhs.averageGrade ?? .zero)
            }
            checkpointNumbers = Self.makeCheckpointNumbers(from: students)
            summary = RatingSummary(students: students)
            logService.log("✅ Rating data loaded for group \(group). Students: \(students.count)")
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            logService.log("❌ Rating API error: \(error.localizedDescription)")
        } catch {
            errorMessage = error.localizedDescription
            logService.log("❌ Unexpected rating error: \(error.localizedDescription)")
        }

        isLoading = false
    }

    private static func makeCheckpointNumbers(from students: [StudentRating]) -> [Int] {
        let numbers = Set(students.flatMap { $0.checkpoints.map { $0.number } })
        return numbers.filter { $0 > 0 }.sorted()
    }
}

#if DEBUG
extension RatingViewModel {
    static var preview: RatingViewModel {
        RatingViewModel(isPreview: true)
    }
}
#endif
