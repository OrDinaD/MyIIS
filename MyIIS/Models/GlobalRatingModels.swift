import Foundation

struct GlobalRatingEntry: Codable, Identifiable, Equatable {
    var id: String { studentCardNumber }

    let studentCardNumber: String
    let average: Double?
    let hours: Int?
    let averageShift: Double?

    let firstAverage: Double?
    let firstHours: Int?
    let secondAverage: Double?
    let secondHours: Int?
    let thirdAverage: Double?
    let thirdHours: Int?
}

struct FacultyDto: Codable, Identifiable, Equatable {
    let id: Int
    let text: String
}

struct SpecialityDto: Codable, Identifiable, Equatable {
    let id: Int
    let text: String
}

struct RatingCourseDto: Codable, Identifiable, Hashable {
    var id: Int { course }

    let course: Int
    let hasForeignPlan: Bool

    var title: String {
        "\(course) курс"
    }

    var subtitle: String? {
        hasForeignPlan ? "Есть иностранный учебный план" : nil
    }
}

struct StudentGlobalRatingDetail: Decodable, Identifiable {
    let id: Int
    let fio: String?
    let subGroup: Int
    let subGroupStudent: Int?
    let lessons: [PortalGradeBookLesson]

    var displayName: String? {
        let trimmed = fio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var totalUnexcusedHours: Int {
        lessons
            .filter { !$0.isRespectfulOmission }
            .reduce(0) { $0 + max($1.gradeBookOmissions, 0) }
    }

    var marks: [Int] {
        lessons.flatMap(\.marks)
    }

    var averageMark: Double? {
        guard !marks.isEmpty else { return nil }
        return Double(marks.reduce(0, +)) / Double(marks.count)
    }

    var subjectCount: Int {
        Set(lessons.map(\.lessonNameAbbrev).filter { !$0.isEmpty }).count
    }
}
