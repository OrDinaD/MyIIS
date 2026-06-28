import Foundation

// MARK: - Rating Models

struct StudentRating: Identifiable, Codable, Equatable {
    let recordBookNumber: String
    let studentName: String?
    let averageGrade: Double?
    let missedHours: Int?
    let averageShift: Double?
    let checkpoints: [RatingCheckpoint]

    var id: String { recordBookNumber }

    private enum CodingKeys: String, CodingKey {
        case recordBookNumber
        case recordBook
        case studentFio
        case studentName
        case averageGrade
        case averageMark
        case missedHours
        case missedLessons
        case averageShift
        case averageShiftMark
        case checkPoint
        case checkPoints
    }

    init(
        recordBookNumber: String,
        studentName: String?,
        averageGrade: Double?,
        missedHours: Int?,
        averageShift: Double?,
        checkpoints: [RatingCheckpoint]
    ) {
        self.recordBookNumber = recordBookNumber
        self.studentName = studentName
        self.averageGrade = averageGrade
        self.missedHours = missedHours
        self.averageShift = averageShift
        self.checkpoints = checkpoints
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.recordBookNumber = container.decodeString(forKeys: [.recordBookNumber, .recordBook]) ?? UUID().uuidString
        self.studentName = container.decodeString(forKeys: [.studentName, .studentFio])
        self.averageGrade = container.decodeDouble(forKeys: [.averageGrade, .averageMark])
        self.missedHours = container.decodeInt(forKeys: [.missedHours, .missedLessons])
        self.averageShift = container.decodeDouble(forKeys: [.averageShift, .averageShiftMark])
        self.checkpoints = container.decodeArray(RatingCheckpoint.self, forKeys: [.checkPoint, .checkPoints])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recordBookNumber, forKey: .recordBookNumber)
        try container.encodeIfPresent(studentName, forKey: .studentName)
        try container.encodeIfPresent(averageGrade, forKey: .averageGrade)
        try container.encodeIfPresent(missedHours, forKey: .missedHours)
        try container.encodeIfPresent(averageShift, forKey: .averageShift)
        try container.encode(checkpoints, forKey: .checkPoints)
    }
}

struct RatingCheckpoint: Identifiable, Codable, Equatable {
    let number: Int
    let title: String?
    let averageGrade: Double?
    let missedHours: Int?

    var id: Int { number }

    private enum CodingKeys: String, CodingKey {
        case number
        case title
        case checkpointNumber
        case pointNumber
        case averageGrade
        case averageMark
        case missedHours
        case missedLessons
    }

    init(number: Int, title: String? = nil, averageGrade: Double?, missedHours: Int?) {
        self.number = number
        self.title = title
        self.averageGrade = averageGrade
        self.missedHours = missedHours
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.number = container.decodeInt(forKeys: [.number, .checkpointNumber, .pointNumber]) ?? 0
        self.title = try? container.decodeIfPresent(String.self, forKey: .title)
        self.averageGrade = container.decodeDouble(forKeys: [.averageGrade, .averageMark])
        self.missedHours = container.decodeInt(forKeys: [.missedHours, .missedLessons])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(number, forKey: .number)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(averageGrade, forKey: .averageGrade)
        try container.encodeIfPresent(missedHours, forKey: .missedHours)
    }
}

struct RatingSummary: Equatable {
    struct CheckpointSummary: Equatable {
        let number: Int
        let averageGrade: Double?
        let totalMissedHours: Int
    }

    let studentCount: Int
    let averageGrade: Double?
    let totalMissedHours: Int
    let averageShift: Double?
    let checkpoints: [CheckpointSummary]

    init?(students: [StudentRating]) {
        guard !students.isEmpty else { return nil }

        studentCount = students.count
        averageGrade = Self.average(of: students.compactMap { $0.averageGrade })
        totalMissedHours = students.compactMap { $0.missedHours }.reduce(0, +)
        averageShift = Self.average(of: students.compactMap { $0.averageShift })

        let grouped = Dictionary(grouping: students.flatMap { $0.checkpoints }) { checkpoint in
            checkpoint.number
        }

        checkpoints = grouped.keys.filter { $0 > 0 }.sorted().map { number in
            let checkpointsForNumber = grouped[number] ?? []
            let avgGrade = Self.average(of: checkpointsForNumber.compactMap { $0.averageGrade })
            let totalMissed = checkpointsForNumber.compactMap { $0.missedHours }.reduce(0, +)
            return CheckpointSummary(number: number, averageGrade: avgGrade, totalMissedHours: totalMissed)
        }
    }

    private static func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }
}

// MARK: - Decoding Helpers

private extension KeyedDecodingContainer {
    func decodeString(forKeys keys: [K]) -> String? {
        for key in keys {
            if let stringValue = try? decodeIfPresent(String.self, forKey: key),
               !stringValue.isEmpty {
                return stringValue
            }
            if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
                return String(intValue)
            }
            if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
                return String(doubleValue)
            }
        }
        return nil
    }

    func decodeDouble(forKeys keys: [K]) -> Double? {
        for key in keys {
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return value
            }
            if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
                let sanitized = stringValue
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: ",", with: ".")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let doubleValue = Double(sanitized) {
                    return doubleValue
                }
            }
        }
        return nil
    }

    func decodeInt(forKeys keys: [K]) -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
                return Int(doubleValue)
            }
            if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
                let sanitized = stringValue
                    .replacingOccurrences(of: " ", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let intValue = Int(sanitized) {
                    return intValue
                }
            }
        }
        return nil
    }

    func decodeArray<T: Decodable>(_ type: T.Type, forKeys keys: [K]) -> [T] {
        for key in keys {
            if let array = try? decodeIfPresent([T].self, forKey: key) {
                return array
            }
        }
        return []
    }
}

// MARK: - Preview Support

extension StudentRating {
    static let previewData: [StudentRating] = {
        let checkpoints1 = [
            RatingCheckpoint(number: 1, title: nil, averageGrade: 8.4, missedHours: 2),
            RatingCheckpoint(number: 2, title: nil, averageGrade: 9.1, missedHours: 0),
            RatingCheckpoint(number: 3, title: nil, averageGrade: 8.8, missedHours: 1)
        ]
        let checkpoints2 = [
            RatingCheckpoint(number: 1, title: nil, averageGrade: 7.9, missedHours: 4),
            RatingCheckpoint(number: 2, title: nil, averageGrade: 8.2, missedHours: 1),
            RatingCheckpoint(number: 3, title: nil, averageGrade: 8.0, missedHours: 3)
        ]
        let checkpoints3 = [
            RatingCheckpoint(number: 1, title: nil, averageGrade: 9.3, missedHours: 0),
            RatingCheckpoint(number: 2, title: nil, averageGrade: 9.0, missedHours: 0),
            RatingCheckpoint(number: 3, title: nil, averageGrade: 9.2, missedHours: 0)
        ]

        return [
            StudentRating(
                recordBookNumber: "42060301",
                studentName: "Анна Ковалёва",
                averageGrade: 8.76,
                missedHours: 3,
                averageShift: 0.4,
                checkpoints: checkpoints1
            ),
            StudentRating(
                recordBookNumber: "42060302",
                studentName: "Кирилл Лавренов",
                averageGrade: 8.1,
                missedHours: 8,
                averageShift: 0.6,
                checkpoints: checkpoints2
            ),
            StudentRating(
                recordBookNumber: "42060303",
                studentName: "Мария Данилова",
                averageGrade: 9.16,
                missedHours: 0,
                averageShift: 0.2,
                checkpoints: checkpoints3
            )
        ]
    }()
}
