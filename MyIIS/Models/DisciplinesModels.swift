import Foundation

struct DisciplineListEntry: Codable, Identifiable {
    var id: String { name }
    let name: String
    let hours: Int?
}
