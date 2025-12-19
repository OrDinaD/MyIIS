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
    private var cachedSpecialityId: Int?
    private var cachedCourse: Int?
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

    /// Загрузка рейтинга с данными образования (оптимизированный метод)
    /// - Parameter education: Данные образования пользователя с кэшированным specialityId
    func loadRating(forEducation education: Education) async {
        await loadRating(forEducation: education, force: false)
    }

    /// Обновление рейтинга с принудительной перезагрузкой
    func refresh(forEducation education: Education) async {
        await loadRating(forEducation: education, force: true)
    }

    /// Устаревший метод - использует дополнительный запрос для получения specialityId
    func loadRating(forGroup group: String?) async {
        await loadRatingLegacy(forGroup: group, force: false)
    }

    func refresh(forGroup group: String?) async {
        await loadRatingLegacy(forGroup: group, force: true)
    }

    /// Оптимизированная загрузка: если есть кэшированный specialityId, пропускаем запрос getScheduleInfo
    private func loadRating(forEducation education: Education, force: Bool) async {
        guard !isPreview else { return }

        let group = education.group
        guard !group.isEmpty else {
            errorMessage = "Не удалось определить номер группы"
            return
        }

        // Проверяем кэш
        if !force,
           currentGroup == group,
           !students.isEmpty,
           cachedSpecialityId == education.specialityDepartmentEducationFormId {
            return
        }

        isLoading = true
        errorMessage = nil

        // Если specialityId доступен - используем быстрый путь
        if let specialityId = education.specialityDepartmentEducationFormId {
            logService.log("🚀 Fast path: Using cached specialityId=\(specialityId) for group \(group)")
            await fetchRatingDirect(
                specialityId: specialityId,
                course: education.course,
                group: group
            )
        } else {
            // Фолбэк на старый метод с дополнительным запросом
            logService.log("⚠️ Slow path: specialityId not cached, fetching for group \(group)")
            await fetchRatingLegacy(group: group)
        }

        isLoading = false
    }

    /// Устаревший метод загрузки (для обратной совместимости)
    private func loadRatingLegacy(forGroup group: String?, force: Bool) async {
        guard !isPreview else { return }

        guard let group = group, !group.isEmpty else {
            errorMessage = "Не удалось определить номер группы"
            return
        }

        if !force, currentGroup == group, !students.isEmpty { return }

        isLoading = true
        errorMessage = nil
        logService.log("⚠️ Legacy: Fetching rating for group \(group) (requires additional API call)")

        await fetchRatingLegacy(group: group)

        isLoading = false
    }

    /// Быстрый запрос рейтинга с уже известными параметрами
    private func fetchRatingDirect(specialityId: Int, course: Int, group: String) async {
        do {
            let response = try await apiService.getRatingDirect(specialityId: specialityId, course: course)
            processRatingResponse(response, group: group, specialityId: specialityId, course: course)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            logService.log("❌ Rating API error: \(error.localizedDescription)")
        } catch {
            errorMessage = error.localizedDescription
            logService.log("❌ Unexpected rating error: \(error.localizedDescription)")
        }
    }

    /// Медленный запрос рейтинга через группу (требует дополнительного запроса)
    private func fetchRatingLegacy(group: String) async {
        do {
            let response = try await apiService.getRating(group: group)
            processRatingResponse(response, group: group, specialityId: nil, course: nil)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
            logService.log("❌ Rating API error: \(error.localizedDescription)")
        } catch {
            errorMessage = error.localizedDescription
            logService.log("❌ Unexpected rating error: \(error.localizedDescription)")
        }
    }

    /// Обработка ответа рейтинга
    private func processRatingResponse(_ response: [StudentRating], group: String, specialityId: Int?, course: Int?) {
        currentGroup = group
        cachedSpecialityId = specialityId
        cachedCourse = course

        // Получаем номер студака текущего пользователя из User.id
        let currentUserId = String(AuthenticationService.shared.currentUser?.id ?? 0)

        // Фильтруем только текущего студента
        if !currentUserId.isEmpty && currentUserId != "0" {
            students = response.filter { $0.recordBookNumber == currentUserId }
        } else {
            students = response.sorted { lhs, rhs in
                (lhs.averageGrade ?? .zero) > (rhs.averageGrade ?? .zero)
            }
        }

        checkpointNumbers = Self.makeCheckpointNumbers(from: students)
        summary = RatingSummary(students: students)
        logService.log("✅ Rating data loaded for group \(group). Students: \(students.count)")
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
