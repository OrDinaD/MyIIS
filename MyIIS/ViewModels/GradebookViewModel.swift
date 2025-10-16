import Foundation
import Combine

@MainActor
final class GradebookViewModel: ObservableObject {

    @Published private(set) var gradebook: Gradebook?
    @Published private(set) var semesters: [GradebookSemester]
    @Published private(set) var averageGrade: Double?
    @Published var isLoading: Bool
    @Published var errorMessage: String?

    private let apiService: APIService
    private var studentId: String?
    private let numberFormatter: NumberFormatter

    init(apiService: APIService = APIService(), initialGradebook: Gradebook? = nil) {
        self.apiService = apiService
        let normalized = initialGradebook?.normalized()
        self.gradebook = normalized
        self.semesters = normalized?.semesters ?? []
        self.averageGrade = normalized?.averageGrade
        self.isLoading = false
        self.errorMessage = nil

        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        self.numberFormatter = formatter
    }

    var hasContent: Bool {
        !semesters.isEmpty
    }

    var averageGradeText: String? {
        guard let averageGrade else {
            return nil
        }
        return numberFormatter.string(from: NSNumber(value: averageGrade)) ?? String(format: "%.2f", averageGrade)
    }

    func loadGradebook(for studentId: String) async {
        self.studentId = studentId
        await fetchGradebook(studentId: studentId)
    }

    func refresh() async {
        guard let studentId else { return }
        await fetchGradebook(studentId: studentId)
    }

    private func fetchGradebook(studentId: String) async {
        guard !studentId.isEmpty else {
            self.errorMessage = "Не указан идентификатор студента."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let gradebook = try await apiService.getGradebook(for: studentId)
            apply(gradebook: gradebook)
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func apply(gradebook: Gradebook) {
        let normalized = gradebook.normalized()
        self.gradebook = normalized
        self.semesters = normalized.semesters
        self.averageGrade = normalized.averageGrade
    }
}

#if DEBUG
extension GradebookViewModel {
    static var preview: GradebookViewModel {
        GradebookViewModel(initialGradebook: .previewData)
    }
}
#endif
