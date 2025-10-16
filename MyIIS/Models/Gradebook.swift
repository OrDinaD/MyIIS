import Foundation

// MARK: - Gradebook Root

struct Gradebook: Codable, Equatable {
    let semesters: [GradebookSemester]

    var isEmpty: Bool {
        semesters.isEmpty
    }

    var averageGrade: Double? {
        let grades = semesters.flatMap { semester in
            semester.disciplines.compactMap { $0.bestGradeValue }
        }

        guard !grades.isEmpty else {
            return nil
        }

        let sum = grades.reduce(0, +)
        return sum / Double(grades.count)
    }

    func normalized() -> Gradebook {
        Gradebook(
            semesters: semesters
                .sorted(by: GradebookSemester.defaultSort)
                .map { $0.normalized() }
        )
    }
}

// MARK: - Gradebook Semester

struct GradebookSemester: Codable, Identifiable, Equatable, Hashable {
    let number: Int
    let title: String?
    let year: String?
    let disciplines: [GradebookDiscipline]

    var id: Int {
        number
    }

    var displayTitle: String {
        if let title, !title.isEmpty {
            return title
        }

        if let year, !year.isEmpty {
            return "Семестр \(number) · \(year)"
        }

        return "Семестр \(number)"
    }

    func normalized() -> GradebookSemester {
        GradebookSemester(
            number: number,
            title: title,
            year: year,
            disciplines: disciplines.sorted(by: GradebookDiscipline.defaultSort)
        )
    }

    func sortedDisciplines() -> [GradebookDiscipline] {
        disciplines.sorted(by: GradebookDiscipline.defaultSort)
    }

    static func defaultSort(lhs: GradebookSemester, rhs: GradebookSemester) -> Bool {
        if lhs.number != rhs.number {
            return lhs.number > rhs.number
        }

        switch (lhs.year, rhs.year) {
        case let (lhsYear?, rhsYear?):
            return lhsYear > rhsYear
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return false
        }
    }
}

// MARK: - Gradebook Discipline

struct GradebookDiscipline: Codable, Identifiable, Equatable, Hashable {
    let code: String
    let name: String
    let controlForm: String
    let teacher: String?
    let hours: Int?
    let attempts: [GradeAttempt]

    var id: String {
        code
    }

    var bestAttempt: GradeAttempt? {
        attempts.max(by: GradeAttempt.bestAttemptSort)
    }

    var latestAttempt: GradeAttempt? {
        sortedAttempts.last
    }

    var sortedAttempts: [GradeAttempt] {
        attempts.sorted { $0.attempt < $1.attempt }
    }

    var bestGradeValue: Double? {
        bestAttempt?.grade.numericValue
    }

    var bestGradeText: String {
        guard let bestAttempt else {
            return "—"
        }
        return bestAttempt.grade.displayValue
    }

    static func defaultSort(lhs: GradebookDiscipline, rhs: GradebookDiscipline) -> Bool {
        let lhsGrade = lhs.bestGradeValue ?? -Double.infinity
        let rhsGrade = rhs.bestGradeValue ?? -Double.infinity

        if lhsGrade != rhsGrade {
            return lhsGrade > rhsGrade
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

// MARK: - Grade Attempt

struct GradeAttempt: Codable, Identifiable, Equatable, Hashable {
    let attempt: Int
    let type: String
    let grade: GradeValue
    let date: String?
    let status: AttemptStatus

    var id: Int {
        attempt
    }

    var title: String {
        "Попытка \(attempt)"
    }

    static func bestAttemptSort(lhs: GradeAttempt, rhs: GradeAttempt) -> Bool {
        let lhsValue = lhs.grade.numericValue ?? -Double.infinity
        let rhsValue = rhs.grade.numericValue ?? -Double.infinity

        if lhsValue != rhsValue {
            return lhsValue < rhsValue
        }

        return lhs.attempt < rhs.attempt
    }

    enum AttemptStatus: Equatable, Hashable {
        case planned
        case passed
        case failed
        case custom(String)
    }
}

extension GradeAttempt.AttemptStatus: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self).uppercased()
        switch value {
        case "PLANNED":
            self = .planned
        case "PASSED":
            self = .passed
        case "FAILED":
            self = .failed
        default:
            self = .custom(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .planned:
            try container.encode("PLANNED")
        case .passed:
            try container.encode("PASSED")
        case .failed:
            try container.encode("FAILED")
        case .custom(let value):
            try container.encode(value)
        }
    }
}

// MARK: - Grade Value

enum GradeValue: Equatable, Hashable {
    case numeric(Double)
    case textual(String)

    var numericValue: Double? {
        switch self {
        case .numeric(let value):
            return value
        case .textual(let text):
            let normalized = text.replacingOccurrences(of: ",", with: ".")
            return Double(normalized)
        }
    }

    var displayValue: String {
        switch self {
        case .numeric(let value):
            return GradeValue.numberFormatter.string(from: NSNumber(value: value)) ?? String(value)
        case .textual(let text):
            return text
        }
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        formatter.groupingSeparator = " "
        return formatter
    }()
}

extension GradeValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let doubleValue = try? container.decode(Double.self) {
            self = .numeric(doubleValue)
            return
        }

        if let intValue = try? container.decode(Int.self) {
            self = .numeric(Double(intValue))
            return
        }

        let stringValue = try container.decode(String.self)
        if let parsed = Double(stringValue.replacingOccurrences(of: ",", with: ".")) {
            self = .numeric(parsed)
        } else {
            self = .textual(stringValue)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .numeric(let value):
            try container.encode(value)
        case .textual(let text):
            try container.encode(text)
        }
    }
}

#if DEBUG
extension Gradebook {
    static let previewData = Gradebook(
        semesters: [
            GradebookSemester(
                number: 6,
                title: "6 семестр",
                year: "2024/2025",
                disciplines: [
                    GradebookDiscipline(
                        code: "AI401",
                        name: "Искусственный интеллект",
                        controlForm: "Курсовой проект",
                        teacher: "Борисова А.А.",
                        hours: 108,
                        attempts: [
                            GradeAttempt(
                                attempt: 1,
                                type: "COURSEWORK",
                                grade: .numeric(10),
                                date: "2025-05-10",
                                status: .passed
                            )
                        ]
                    ),
                    GradebookDiscipline(
                        code: "MATH301",
                        name: "Математический анализ",
                        controlForm: "Экзамен",
                        teacher: "Петров П.П.",
                        hours: 144,
                        attempts: [
                            GradeAttempt(
                                attempt: 1,
                                type: "EXAM",
                                grade: .numeric(8.5),
                                date: "2025-06-25",
                                status: .passed
                            )
                        ]
                    )
                ]
            ),
            GradebookSemester(
                number: 5,
                title: "5 семестр",
                year: "2023/2024",
                disciplines: [
                    GradebookDiscipline(
                        code: "ALG101",
                        name: "Алгоритмы",
                        controlForm: "Экзамен",
                        teacher: "Иванов И.И.",
                        hours: 144,
                        attempts: [
                            GradeAttempt(
                                attempt: 1,
                                type: "EXAM",
                                grade: .numeric(6),
                                date: "2024-01-15",
                                status: .failed
                            ),
                            GradeAttempt(
                                attempt: 2,
                                type: "EXAM",
                                grade: .numeric(9),
                                date: "2024-02-02",
                                status: .passed
                            )
                        ]
                    ),
                    GradebookDiscipline(
                        code: "HIST202",
                        name: "История",
                        controlForm: "Зачёт",
                        teacher: "Сидорова С.С.",
                        hours: 72,
                        attempts: [
                            GradeAttempt(
                                attempt: 1,
                                type: "CREDIT",
                                grade: .textual("зачёт"),
                                date: "2024-01-10",
                                status: .passed
                            )
                        ]
                    )
                ]
            )
        ]
    )
    .normalized()
}
#endif
