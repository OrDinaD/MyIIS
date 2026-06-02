import Foundation

struct MarkbookResponse: Codable, Equatable {
    let number: String
    let averageMark: Double
    let markPages: [String: MarkbookSemester]
}

struct MarkbookSemester: Codable, Equatable {
    let averageMark: Double
    let marks: [MarkbookMark]
}

struct MarkbookMark: Codable, Equatable, Identifiable {
    let subject: String
    let formOfControl: String
    let fullSubject: String
    let hours: String
    let credits: Double?
    let mark: String
    let date: String?
    let teacher: String?
    let commonMark: Double?
    let commonRetakes: Double?
    let retakesCount: Int

    var id: String {
        "\(subject)|\(formOfControl)|\(date ?? "")|\(mark)"
    }

    var displayHours: String {
        guard let credits else { return hours }
        return "\(hours) (\(credits.formatted(.number.precision(.fractionLength(1)))) з.е.)"
    }

    var displayGrade: String {
        mark
    }

    var averageForLastFourYearsText: String? {
        guard let commonMark else { return nil }
        return commonMark.formatted(.number.precision(.fractionLength(2)))
    }

    var displayRetakes: String {
        if let commonRetakes {
            let percent = (commonRetakes * 100).formatted(.number.precision(.fractionLength(1)))
            return "\(retakesCount) (\(percent)%)"
        }
        return "\(retakesCount)"
    }

    var hasExpandedFullName: Bool {
        fullSubject.trimmingCharacters(in: .whitespacesAndNewlines) != subject.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
