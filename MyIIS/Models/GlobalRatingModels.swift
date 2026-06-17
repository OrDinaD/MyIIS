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
    var id: Int { self.id_ }
    private let id_: Int
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case id_ = "id"
        case text
    }
}

struct SpecialityDto: Codable, Identifiable {
    var id: Int { id_ }
    private let id_: Int
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case id_ = "id"
        case text
    }
}
