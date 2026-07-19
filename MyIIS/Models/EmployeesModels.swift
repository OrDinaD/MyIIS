import Foundation

// MARK: - API DTOs

struct DepartmentTreeNodeDTO: Decodable, Identifiable, Sendable {
    var id: Int { data.id }
    let data: DepartmentNodeDataDTO
    let children: [DepartmentTreeNodeDTO]?
}

struct DepartmentNodeDataDTO: Decodable, Sendable {
    let id: Int
    let typeId: Int
    let name: String
    let abbrev: String?
    let idHead: Int?
    let employees: [DepartmentEmployeeLiteDTO]?
    let code: String?
    let urlId: String?
}

struct DepartmentEmployeeLiteDTO: Decodable, Sendable {
    let fio: String
    let phoneNumbers: [String]?
}

struct EmployeeSummaryDTO: Decodable, Sendable {
    let id: Int
    let firstName: String
    let middleName: String
    let lastName: String
    let photoLink: URL?
    let degree: String?
    let degreeAbbrev: String?
    let rank: String?
    let email: String?
    let urlId: String
    let calendarId: String?
    let jobPositions: [EmployeeJobPositionDTO]?
    let chief: Bool?

    nonisolated func getFullName() -> String {
        [lastName, firstName, middleName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct EmployeeJobPositionDTO: Decodable, Sendable {
    let employeeDepartmentId: Int?
    let jobPosition: String?
    let department: String?
    let contacts: [EmployeeContactDTO]?
}

struct EmployeeContactDTO: Decodable, Hashable, Sendable {
    let phoneId: Int?
    let phoneNumber: String?
    let address: String?
    let auditory: String?
    let buildingNumber: String?
    let department: String?
}

struct EmployeeDetailsDTO: Decodable, Sendable {
    let id: Int
    let firstName: String
    let middleName: String
    let lastName: String
    let photoLink: URL?
    let degree: String?
    let degreeAbbrev: String?
    let rank: String?
    let email: String?
    let urlId: String
    let calendarId: String?
    let jobPositions: [EmployeeJobPositionDTO]?
    let readingCourses: [String]?
    let additionalInformation: [EmployeeAdditionalInformationDTO]?
    let profileLinks: [EmployeeProfileLinkDTO]?
    let chief: Bool?
}

struct EmployeeAdditionalInformationDTO: Decodable, Sendable {
    let id: Int?
    let idType: Int
    let nameType: String
    let content: String?
}

struct EmployeeProfileLinkDTO: Decodable, Hashable, Sendable {
    let profileLinkType: String
    let link: String
}

// MARK: - Domain Models

enum DepartmentKind: Sendable, Hashable {
    case administrative
    case faculty
    case academicDepartment
    case deanOffice
    case researchOrOther
    case unknown(Int)
    
    init(typeId: Int) {
        switch typeId {
        case 1: self = .administrative
        case 2: self = .faculty
        case 3: self = .academicDepartment
        case 4: self = .deanOffice
        case 5: self = .researchOrOther
        default: self = .unknown(typeId)
        }
    }
}

struct PersonName: Hashable, Sendable {
    var firstName: String
    var lastName: String
    var middleName: String
    nonisolated func getFullName() -> String {
        [lastName, firstName, middleName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct EmployeePosition: Hashable, Sendable {
    var departmentId: Int?
    var departmentName: String
    var title: String
    var contacts: [EmployeeContact]
}

struct EmployeeContact: Hashable, Sendable {
    var phone: String?
    var address: String?
}

struct EmployeeInfoSection: Identifiable, Sendable {
    var id: Int { idType }
    let idType: Int
    let title: String
    let htmlContent: String
}

struct EmployeeLink: Hashable, Sendable {
    let type: String
    let url: URL
}

struct EmployeeProfile: Identifiable, Sendable {
    let id: Int
    var urlId: String
    var name: PersonName
    var photoURL: URL?

    var degree: String?
    var degreeAbbreviation: String?
    var rank: String?
    var email: String?
    var calendarId: String?

    var positions: [EmployeePosition]
    var departmentLeadership: [String: Bool] // departmentUrlId -> chief
    var readingCourses: [String]
    var additionalSections: [EmployeeInfoSection]
    var profileLinks: [EmployeeLink]
}

struct EmployeeSearchHit: Identifiable, Hashable, Sendable {
    var id: String { "\(departmentUrlId)|\(normalizedFIO)|\(phones.joined(separator: ","))" }

    let fio: String
    let normalizedFIO: String
    let surname: String
    let phones: [String]

    let departmentId: Int
    let departmentUrlId: String
    let departmentName: String
    let departmentAbbrev: String
    let departmentTypeId: Int
}
