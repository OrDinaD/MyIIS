import Foundation

struct DepartmentNode: Codable, Identifiable {
    let data: DepartmentData
    let children: [DepartmentNode]?
    
    var id: Int { data.id }
}

struct DepartmentData: Codable, Identifiable {
    let id: Int
    let typeId: Int?
    let name: String
    let abbrev: String?
    let idHead: Int?
    let employees: [DepartmentEmployee]?
    let code: String?
    let urlId: String?
}

struct DepartmentEmployee: Codable {
    let fio: String
    let phoneNumbers: [String]?
}
