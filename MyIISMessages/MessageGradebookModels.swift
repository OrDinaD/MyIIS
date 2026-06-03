import Foundation
import SwiftUI

struct MessageGradebookSection: Identifiable {
    let semester: MessageGradebookSnapshot.Semester
    let subjects: [MessageGradebookSnapshot.Subject]

    var id: String {
        semester.id
    }
}

struct MessageShareItem: Identifiable {
    enum Kind {
        case overall
        case semester(String)
        case subject(semesterID: String, subjectID: String)
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let fileName: String
    let symbolName: String
    let accent: Color

    init(overall snapshot: MessageGradebookSnapshot) {
        id = "overall"
        kind = .overall
        title = "Вся зачетка"
        subtitle = "Номер \(snapshot.number) · общий средний \(snapshot.overallAverageText)"
        fileName = "myiis-gradebook-overall.png"
        symbolName = "graduationcap.fill"
        accent = Color(red: 0.00, green: 0.44, blue: 0.39)
    }

    init(semester: MessageGradebookSnapshot.Semester) {
        id = "semester-\(semester.id)"
        kind = .semester(semester.id)
        title = semester.title
        subtitle = "Предметов: \(semester.subjects.count) · средний \(semester.averageText)"
        fileName = "myiis-gradebook-semester-\(semester.id.sanitizedForFileName).png"
        symbolName = "books.vertical.fill"
        accent = Color(red: 0.25, green: 0.30, blue: 0.63)
    }

    init(subject: MessageGradebookSnapshot.Subject, semester: MessageGradebookSnapshot.Semester) {
        id = "subject-\(semester.id)-\(subject.id)"
        kind = .subject(semesterID: semester.id, subjectID: subject.id)
        title = subject.abbreviation
        subtitle = "\(subject.fullName) · \(subject.grade)"
        fileName = "myiis-gradebook-\(subject.abbreviation.sanitizedForFileName).png"
        symbolName = "checkmark.seal.fill"
        accent = Color(red: 0.72, green: 0.41, blue: 0.09)
    }

    static func summaryItems(from snapshot: MessageGradebookSnapshot) -> [MessageShareItem] {
        var items = [MessageShareItem(overall: snapshot)]
        if let latestSemester = snapshot.latestSemester {
            items.append(MessageShareItem(semester: latestSemester))
        }
        return items
    }
}
struct MessageGradebookSnapshot: Codable, Equatable {
    let number: String
    let overallAverageText: String
    let updatedAt: Date
    let semesters: [Semester]

    var latestSemester: Semester? {
        semesters.last
    }

    func semester(id: String) -> Semester? {
        semesters.first { $0.id == id }
    }

    struct Semester: Codable, Equatable, Identifiable {
        let id: String
        let averageText: String
        let subjects: [Subject]

        var title: String {
            "Семестр \(id)"
        }

        func subject(id: String) -> Subject? {
            subjects.first { $0.id == id }
        }
    }

    struct Subject: Codable, Equatable, Identifiable {
        let id: String
        let abbreviation: String
        let fullName: String
        let controlForm: String
        let grade: String
        let averageText: String
        let retakesText: String
        let dateText: String
        let teacherText: String
    }
}

enum MessageGradebookDataStore {
    private enum Key {
        static let snapshot = "myiis_gradebook_message_snapshot_v1"
    }

    private static let appGroupIdentifier = "group.com.OrDinaD.MyIIS"

    private static var defaults: UserDefaults? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil else {
            return nil
        }
        return UserDefaults(suiteName: appGroupIdentifier)
    }

    static func loadSnapshot() -> MessageGradebookSnapshot? {
        guard let defaults, let data = MessagePayloadStore.load(forKey: Key.snapshot, from: defaults) else {
            return nil
        }
        return try? JSONDecoder().decode(MessageGradebookSnapshot.self, from: data)
    }
}

private enum MessagePayloadStore {
    private static let maxPayloadBytes = 3_500_000

    static func load(forKey key: String, from defaults: UserDefaults) -> Data? {
        guard let data = defaults.data(forKey: key), data.count < maxPayloadBytes else {
            return nil
        }
        return data
    }
}

private extension String {
    var sanitizedForFileName: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let value = String(unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        })
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        return value.isEmpty ? "gradebook" : value
    }
}
