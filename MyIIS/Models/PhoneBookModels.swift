import Foundation

struct PhoneBookResponse: Codable {
    let auditoryPhoneNumberDtoList: [PhoneBookEntry]
    let totalItems: Int
}

struct PhoneBookEntry: Codable, Identifiable {
    var id: String { auditory + (phones.first ?? "") }
    
    let auditory: String
    let phones: [String]
    let employees: [PhoneBookEmployee]
    let departments: [PhoneBookDepartment]
    let note: String?
    let buildingAddress: String?
}

struct PhoneBookEmployee: Codable, Identifiable {
    var id: String { "\(employeeId)-\(UUID().uuidString)" }
    let employeeId: Int
    let fio: String
    let degree: String?
    let rank: String?
    let jobPosition: String?
    let department: String?
    let photoLink: String?
    let email: String?
    let urlId: String?

    private enum CodingKeys: String, CodingKey {
        case employeeId = "id"
        case fio, degree, rank, jobPosition, department, photoLink, email, urlId
    }
}

struct PhoneBookDepartment: Codable, Identifiable {
    var id: String { abbrev }
    let name: String
    let abbrev: String
}
