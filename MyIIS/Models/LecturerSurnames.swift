import Foundation

enum LecturerSurnames {
    nonisolated static func key(_ subject: String) -> String {
        subject.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    nonisolated static func group(_ lessons: [DisciplineSchedule]) -> [String: String] {
        var surnames: [String: Set<String>] = [:]
        for lesson in lessons where key(lesson.lessonTypeAbbrev) == "лк" {
            let subject = key(lesson.subject)
            guard !subject.isEmpty else { continue }
            for employee in lesson.employees {
                guard let surname = employee.lastName?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !surname.isEmpty else { continue }
                surnames[subject, default: []].insert(surname)
            }
        }
        return surnames.mapValues { $0.sorted().joined(separator: ", ") }
    }
}
