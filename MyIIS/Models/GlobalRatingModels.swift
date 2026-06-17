import Foundation

struct GlobalRatingEntry: Codable, Identifiable {
    var id: String { studentCardNumber }
    
    let studentCardNumber: String
    let average: Double?
    let hours: Int?
    let averageShift: Double?
    
    let firstAverage: Double?
    let firstHours: Int?
    let secondAverage: Double?
    let secondHours: Int?
    let thirdAverage: Double?
    let thirdHours: Int?
}

struct FacultyDto: Codable, Identifiable {
    var id: Int { self.id_ } // The property is usually id, but let's check
    private let id_: Int
    let name: String
    let abbrev: String
    
    enum CodingKeys: String, CodingKey {
        case id_ = "id"
        case name
        case abbrev
    }
}

struct SpecialityDto: Codable, Identifiable {
    var id: Int { id_ }
    private let id_: Int
    let name: String
    let abbrev: String
    let code: String
    let educationForm: EducationFormDto?
    
    enum CodingKeys: String, CodingKey {
        case id_ = "id"
        case name
        case abbrev
        case code
        case educationForm
    }
}

struct EducationFormDto: Codable {
    let id: Int
    let name: String
}
