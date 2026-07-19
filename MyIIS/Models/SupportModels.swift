import Foundation

// MARK: - API DTOs

struct BugReportCategoryDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let categoryName: String
    let categoryKey: String
    let bugReportSubcategoriesDto: [BugReportSubcategoryDTO]?
}

struct BugReportSubcategoryDTO: Decodable, Identifiable, Hashable {
    let id: Int
    let subcategoryName: String
    let subcategoryKey: String
}

struct AutocompleteRequest: Encodable {
    let login: String
    let password: String // DO NOT log
}

struct AutocompleteResponse: Decodable {
    let fio: String?
    let email: String?
    let phone: String?
    let accountType: String?
    let department: String?
    let room: String?
    let building: String?
    let group: String?
}

struct AutocompletePersonalInfoRequest: Encodable {
    let fio: String
    let email: String
}

struct AutocompletePersonalInfoResponse: Decodable {
    let phone: String?
    let department: String?
    let room: String?
    let building: String?
}

struct DepartmentFilterResponse: Decodable {
    let name: String
    let abbrev: String
    let code: String?
}

struct AuditoryFilterResponse: Decodable {
    let name: String
    let buildingNumber: String?
    
    // Sometimes buildingNumber comes as Int
    enum CodingKeys: String, CodingKey {
        case name, buildingNumber
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        if let str = try? container.decodeIfPresent(String.self, forKey: .buildingNumber) {
            buildingNumber = str
        } else if let num = try? container.decodeIfPresent(Int.self, forKey: .buildingNumber) {
            buildingNumber = String(num)
        } else {
            buildingNumber = nil
        }
    }
}

// MARK: - Local Models

struct SupportDocumentItem: Identifiable {
    let id = UUID()
    let number: String
    let title: String
    let path: String
    let url: URL
}

struct SupportDocumentGroup: Identifiable {
    let id = UUID()
    let groupNumber: Int
    let groupName: String
    let localNetworkOnly: Bool
    let note: String?
    let items: [SupportDocumentItem]
}

enum SupportField: String, CaseIterable, Hashable {
    case description
    case phone
    case department
    case roomBuilding
    case computerName
    case printerName
    case inventoryNumber
    case acts
}

struct EquipmentAct: Identifiable, Codable {
    var id = UUID()
    var key: Int = 0 // Needs mapping before send
    var department: String = ""
    var equipmentType: String = ""
    var inventoryNumber: String = ""
    var year: String = ""
    var fullName: String = ""
    var phoneNumber: String = ""
}