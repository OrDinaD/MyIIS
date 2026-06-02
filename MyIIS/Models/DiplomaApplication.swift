import Foundation

struct DiplomaPersonalInformation: Codable, Equatable {
    let degree: Int?
    let email: String?
    let phone: String?
    let course: Int?
    let enablePractice: Bool?
    let practiceType: String?
    let graduating: Bool
    let supportsKt: Bool?
    let supportsRe: Bool?
    let belarusian: Bool?

    private enum CodingKeys: String, CodingKey {
        case degree
        case email
        case phone
        case course
        case enablePractice
        case practiceType
        case graduating
        case supportsKt = "kt"
        case supportsRe = "re"
        case belarusian
    }
}

struct DiplomaApplication: Codable, Identifiable, Equatable {
    let id: Int
    let date: String?
    let employee: DiplomaEmployee?
    let externalManager: DiplomaExternalManager?
    let topic: String
    let belarusianTopic: String?
    let englishTopic: String?
    let justification: String?
    let rejectionReason: String?
    let status: String
    let statusId: Int

    var supervisorName: String {
        if let employee {
            return employee.displayName
        }
        if let externalManager {
            return externalManager.displayName
        }
        return "Руководитель не указан"
    }

    var canCancel: Bool {
        statusId == 5
    }

    var canDownloadApplication: Bool {
        ![3, 4, 5].contains(statusId)
    }
}

struct DiplomaEmployee: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let middleName: String?
    let fio: String?
    let academicDepartment: String?
    let price: Double?

    var displayName: String {
        if let fio, !fio.isEmpty {
            return fio
        }
        return [lastName, firstName, middleName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var subtitle: String? {
        guard let academicDepartment, !academicDepartment.isEmpty else { return nil }
        return academicDepartment
    }
}

struct DiplomaExternalManager: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let firstName: String?
    let lastName: String?
    let middleName: String?
    let scienceDegree: DiplomaNamedValue?
    let employeeRank: DiplomaNamedValue?
    let workPlace: String?
    let jobPosition: String?

    var displayName: String {
        [lastName, firstName, middleName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var subtitle: String? {
        [scienceDegree?.displayName, employeeRank?.displayName, jobPosition, workPlace]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            .nilIfEmpty
    }
}

struct DiplomaNamedValue: Codable, Equatable, Hashable {
    let id: Int?
    let name: String?
    let abbrev: String?
    let price: Double?

    var displayName: String? {
        if let abbrev, !abbrev.isEmpty {
            return abbrev
        }
        if let name, !name.isEmpty {
            return name
        }
        return nil
    }
}

struct DiplomaEmployeeTopic: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    let topic: String
}

enum DiplomaSupervisor: Identifiable, Equatable, Hashable {
    case employee(DiplomaEmployee)
    case external(DiplomaExternalManager)

    var id: String {
        switch self {
        case .employee(let employee):
            return "employee-\(employee.id)"
        case .external(let manager):
            return "external-\(manager.id)"
        }
    }

    var title: String {
        switch self {
        case .employee(let employee):
            return employee.displayName
        case .external(let manager):
            return manager.displayName
        }
    }

    var subtitle: String? {
        switch self {
        case .employee(let employee):
            return employee.subtitle
        case .external(let manager):
            return manager.subtitle
        }
    }

    var employeeId: Int? {
        if case .employee(let employee) = self {
            return employee.id
        }
        return nil
    }

    var externalManagerId: Int? {
        if case .external(let manager) = self {
            return manager.id
        }
        return nil
    }

    var isExternal: Bool {
        if case .external = self {
            return true
        }
        return false
    }
}

struct DiplomaApplicationPayload: Encodable {
    let employeeId: Int?
    let externalManagerId: Int?
    let topicName: String
    let englishTopic: String?
    let belarusianTopic: String?
    let justification: String?
}

struct DiplomaContext: Codable, Equatable {
    let personalInformation: DiplomaPersonalInformation
    let applications: [DiplomaApplication]
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
