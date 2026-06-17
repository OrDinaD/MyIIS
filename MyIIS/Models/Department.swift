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

struct DepartmentEmployeeDetail: Codable, Identifiable {
    let id: Int
    let firstName: String
    let middleName: String?
    let lastName: String
    let photoLink: String?
    let email: String?
    let urlId: String?
    let jobPositions: [DepartmentEmployeeJobPosition]?
    
    var fio: String {
        let mid = middleName ?? ""
        return "\\(lastName) \\(firstName) \\(mid)".trimmingCharacters(in: .whitespaces)
    }
}

struct DepartmentEmployeeJobPosition: Codable {
    let jobPosition: String?
    let department: String?
    let contacts: [DepartmentEmployeeContact]?
}

struct DepartmentEmployeeContact: Codable {
    let phoneNumber: String?
    let address: String?
}
