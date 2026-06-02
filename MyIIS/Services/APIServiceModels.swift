import Foundation

// MARK: - API Data Models

struct LoginRequest: Codable {
    let username: String
    let password: String
}

// Реальный ответ от API БГУИР при логине
struct LoginResponse: Codable {
    let username: String
    let fio: String
    let email: String
    let authorities: [String]
    let accountType: String
    let phone: String
    let group: String
    let photoUrl: String?
    let isGroupHead: Bool
    let canStudentNote: Bool
    let hasNotConfirmedContact: Bool
    let hasProfiling: Bool
}

// Профиль пользователя из /profiles/personal-profile
struct PersonalProfile: Codable {
    let firstName: String?
    let lastName: String?
    let middleName: String?
    let belarusianFirstName: String?
    let belarusianLastName: String?
    let belarusianMiddleName: String?
    let birthDate: String? // Формат: "dd.MM.yyyy"
    let photoUrl: String?
    let course: Int?
    let faculty: String?
    let speciality: String?
    let studentGroup: String?
    let rating: Int?
}

// Информация из расписания группы
struct ScheduleResponse: Codable {
    let studentGroupDto: StudentGroupDto?
}

struct StudentGroupDto: Codable {
    let name: String
    let facultyId: Int
    let facultyAbbrev: String
    let facultyName: String
    let specialityDepartmentEducationFormId: Int?
    let specialityName: String
    let specialityAbbrev: String
    let course: Int
    let id: Int?
    let educationDegree: Int?
}

// Упрощённая структура для передачи данных
struct ScheduleInfo {
    let facultyAbbrev: String
    let facultyName: String
    let specialityAbbrev: String
    let specialityName: String
    let course: Int
    let specialityDepartmentEducationFormId: Int?
    let studentGroupId: Int?
    let educationDegree: Int?
}

private enum RemoteStudentRatingCodingKey: String, CodingKey {
    case studentCardNumber
    case recordBookNumber
    case average
    case averageGrade
    case hours
    case missedHours
    case averageShift
    case checkPoint
    case checkPoints
    case firstAverage, firstHours
    case secondAverage, secondHours
    case thirdAverage, thirdHours
    case fourthAverage, fourthHours
    case fifthAverage, fifthHours
    case sixthAverage, sixthHours
}

private struct RemoteCheckpointDescriptor {
    let averageKey: RemoteStudentRatingCodingKey
    let hoursKey: RemoteStudentRatingCodingKey
    let number: Int
}

struct RemoteStudentRating: Decodable {
    let studentCardNumber: String
    let average: Double?
    let hours: Int?
    let averageShift: Double?
    let checkpoints: [RatingCheckpoint]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RemoteStudentRatingCodingKey.self)

        if let cardNumber = try? container.decode(String.self, forKey: .studentCardNumber) {
            studentCardNumber = cardNumber
        } else {
            studentCardNumber = try container.decode(String.self, forKey: .recordBookNumber)
        }

        average = (try? container.decodeIfPresent(Double.self, forKey: .average))
            ?? (try? container.decodeIfPresent(Double.self, forKey: .averageGrade))

        hours = (try? container.decodeIfPresent(Int.self, forKey: .hours))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .missedHours))

        averageShift = try container.decodeIfPresent(Double.self, forKey: .averageShift)

        if let directCheckpoints = try? container.decode([RatingCheckpoint].self, forKey: .checkPoint),
           !directCheckpoints.isEmpty {
            checkpoints = directCheckpoints
            return
        }
        if let directCheckpoints = try? container.decode([RatingCheckpoint].self, forKey: .checkPoints),
           !directCheckpoints.isEmpty {
            checkpoints = directCheckpoints
            return
        }

        let descriptors: [RemoteCheckpointDescriptor] = [
            .init(averageKey: .firstAverage, hoursKey: .firstHours, number: 1),
            .init(averageKey: .secondAverage, hoursKey: .secondHours, number: 2),
            .init(averageKey: .thirdAverage, hoursKey: .thirdHours, number: 3),
            .init(averageKey: .fourthAverage, hoursKey: .fourthHours, number: 4),
            .init(averageKey: .fifthAverage, hoursKey: .fifthHours, number: 5),
            .init(averageKey: .sixthAverage, hoursKey: .sixthHours, number: 6)
        ]

        checkpoints = try descriptors.compactMap { descriptor in
            let avg = try container.decodeIfPresent(Double.self, forKey: descriptor.averageKey)
            let missed = try container.decodeIfPresent(Int.self, forKey: descriptor.hoursKey)
            if avg == nil && missed == nil {
                return nil
            }
            return RatingCheckpoint(number: descriptor.number, averageGrade: avg, missedHours: missed)
        }
    }

    func toStudentRating() -> StudentRating {
        StudentRating(
            recordBookNumber: studentCardNumber,
            studentName: nil,
            averageGrade: average,
            missedHours: hours,
            averageShift: averageShift,
            checkpoints: checkpoints
        )
    }
}
