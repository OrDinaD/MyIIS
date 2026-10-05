import Foundation
import Observation

@MainActor
@Observable
final class HeadmanJournalViewModel {
    enum Page: String, CaseIterable {
        case attendance = "Посещаемость"
        case topics = "Темы"
        case summary = "Сводка"
    }

    var page: Page = .attendance
    var topicSubgroup = 0
    var options: [HeadmanJournalOption] = []
    var students: [HeadmanJournalStudent] = []
    var selectedID: Int?
    var data: HeadmanJournalData?
    var isLoading = false
    var isSaving = false
    var error: String?
    var success: String?
    var accessDenied = false
    private var generation = 0
    private var ownerID: Int?
    private let api = APIService()

    var canWrite: Bool {
        !APIService.isDemoMode && !accessDenied && data != nil && !isLoading && !isSaving
            && ownerID == AuthenticationService.shared.currentUser?.id
            && AuthenticationService.shared.currentUser?.isHeadmanOrNoteAllowed == true
    }

    var selectedOption: HeadmanJournalOption? { options.first { $0.id == selectedID } }

    func loadIfNeeded() async {
        guard !isLoading else { return }
        if data != nil, ownerID == AuthenticationService.shared.currentUser?.id { return }
        await reload()
    }

    func reload() async {
        generation += 1
        let token = generation
        isLoading = true
        error = nil
        success = nil
        data = nil
        guard let user = AuthenticationService.shared.currentUser, user.isHeadmanOrNoteAllowed else {
            accessDenied = true
            options = []
            students = []
            isLoading = false
            return
        }
        ownerID = user.id
        accessDenied = false
        do {
            async let subjects = api.getHeadmanJournalSubjects()
            async let roster = api.getHeadmanJournalStudents()
            let (loadedSubjects, loadedStudents) = try await (subjects, roster)
            guard token == generation, ownerID == AuthenticationService.shared.currentUser?.id else { return }
            options = loadedSubjects.flatMap { name, values in
                values.map { HeadmanJournalOption(name: name, subject: $0) }
            }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            students = loadedStudents.sorted {
                $0.fullName.localizedStandardCompare($1.fullName) == .orderedAscending
            }
            if !options.contains(where: { $0.id == selectedID }) { selectedID = options.first?.id }
            if let selectedID {
                let loaded = try await api.getHeadmanJournalData(termHoursID: selectedID)
                guard token == generation else { return }
                data = loaded
            }
        } catch {
            guard token == generation else { return }
            handle(error)
        }
        if token == generation { isLoading = false }
    }

    func select(_ id: Int) async {
        generation += 1
        let token = generation
        selectedID = id
        data = nil
        error = nil
        success = nil
        isLoading = true
        do {
            let loaded = try await api.getHeadmanJournalData(termHoursID: id)
            guard token == generation, ownerID == AuthenticationService.shared.currentUser?.id else { return }
            data = loaded
        } catch {
            if token == generation { handle(error) }
        }
        if token == generation { isLoading = false }
    }

    func save(lesson: HeadmanJournalData.Lesson, hours: [Int: Int]) async -> Bool {
        guard canWrite, let data,
              data.lessons.contains(where: { $0.id == lesson.id }), lesson.numberOfHours > 0, !hours.isEmpty,
              hours.allSatisfy({ studentID, value in
                  (1...max(lesson.numberOfHours, 1)).contains(value)
                      && data.contains(studentID: studentID, lesson: lesson)
                      && data.record(studentID: studentID, lessonID: lesson.id) == nil
              }) else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            let result = try await api.saveHeadmanJournalOmissions(
                lessonID: lesson.id,
                omissions: hours.sorted { $0.key < $1.key }.map {
                    HeadmanStudentOmissionHours(student: $0.key, hours: $0.value)
                }
            )
            guard ownerID == AuthenticationService.shared.currentUser?.id else {
                self.data = nil
                return false
            }
            guard hours.allSatisfy({ result[String($0.key)]?.missedHours == $0.value }) else {
                self.data = nil
                error = String(localized: "Сервер вернул неполный результат. Обновите журнал для проверки.")
                return false
            }
            // Apply the authoritative POST response before refreshing: never retry an acknowledged write.
            for index in self.data?.attendance.indices ?? 0..<0 {
                guard let studentID = self.data?.attendance[index].studentId,
                      let record = result[String(studentID)] else { continue }
                self.data?.attendance[index].lessonRecords[String(lesson.id)] = record
            }
            success = String(localized: "Пропуски сохранены.")
            return true
        } catch {
            handle(error)
            self.data = nil
            self.error = String(localized: "Не удалось подтвердить сохранение. Обновите журнал перед повторной отправкой.")
                + " " + error.localizedDescription
            return false
        }
    }

    func saveTopic(lesson: HeadmanJournalData.Lesson, topic: String) async -> Bool {
        guard canWrite, data?.lessons.contains(where: { $0.id == lesson.id }) == true else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            let result = try await api.saveHeadmanJournalTopic(lessonID: lesson.id, topic: topic)
            guard ownerID == AuthenticationService.shared.currentUser?.id else {
                data = nil
                return false
            }
            guard result.lessonId == lesson.id else {
                data = nil
                error = String(localized: "Сервер вернул неполный результат. Обновите журнал для проверки.")
                return false
            }
            if let index = data?.lessons.firstIndex(where: { $0.id == result.lessonId }) {
                data?.lessons[index].topic = result.topic
            }
            success = String(localized: "Тема сохранена.")
            return true
        } catch {
            handle(error)
            self.data = nil
            self.error = String(localized: "Не удалось подтвердить сохранение. Обновите журнал перед повторной отправкой.")
                + " " + error.localizedDescription
            return false
        }
    }

    private func handle(_ failure: Error) {
        if case APIError.unauthorized = failure {
            accessDenied = true
            data = nil
        }
        if case APIError.serverError(let code, _) = failure, code == 403 || code == 401 {
            accessDenied = true
            data = nil
        }
        error = failure.localizedDescription
    }
}
