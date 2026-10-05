import Foundation

struct HeadmanJournalStudent: Decodable, Identifiable {
    let studentId: Int
    let fullName: String
    let educationStatus: String?
    var id: Int { studentId }
}

struct HeadmanJournalSubject: Decodable, Identifiable {
    let id: Int
    let hasSubGroups: Bool
    let lessonTypeAbbrev: String
    let teacherInfo: TeacherInfo?
    struct TeacherInfo: Decodable {
        let fullName: String
        let email: String?
    }
}

struct HeadmanJournalOption: Identifiable {
    let name: String
    let subject: HeadmanJournalSubject
    var id: Int { subject.id }
    var title: String { "\(name) · \(subject.lessonTypeAbbrev)" }
}

struct HeadmanJournalData: Decodable {
    var attendance: [Attendance]
    var lessons: [Lesson]
    let subgroupsCount: Int

    struct Attendance: Decodable {
        let studentId: Int
        let subGroup: Int?
        var lessonRecords: [String: HeadmanOmission?]
    }

    struct Lesson: Decodable, Identifiable {
        let id: Int
        let date: String
        let subgroup: Int
        var topic: String?
        let numberOfHours: Int
    }

    var topicSubgroups: [Int] {
        Array(Set(lessons.map(\.subgroup).filter { $0 > 0 })).sorted()
    }

    func topicLessons(subgroup: Int) -> [Lesson] {
        lessons.filter { subgroup == 0 || $0.subgroup == 0 || $0.subgroup == subgroup }
            .sorted { ($0.date, $0.id) < ($1.date, $1.id) }
    }

    func record(studentID: Int, lessonID: Int) -> HeadmanOmission? {
        attendance.first { $0.studentId == studentID }?.lessonRecords[String(lessonID)].flatMap { $0 }
    }

    func contains(studentID: Int, lesson: Lesson) -> Bool {
        guard let row = attendance.first(where: { $0.studentId == studentID }),
              row.lessonRecords.keys.contains(String(lesson.id)) else { return false }
        return lesson.subgroup == 0 || row.subGroup == lesson.subgroup
    }
}

struct HeadmanTopicRequest: Codable {
    let lessonId: Int
    let topic: String
}
