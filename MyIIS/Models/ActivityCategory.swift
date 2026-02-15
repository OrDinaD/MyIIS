import Foundation

struct ActivityCategory: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let shortDescription: String?
    let iconSystemName: String

    init(id: Int, name: String, shortDescription: String? = nil, iconSystemName: String = "sparkles") {
        self.id = id
        self.name = name
        self.shortDescription = shortDescription
        self.iconSystemName = iconSystemName
    }
}

// MARK: - Previews

extension ActivityCategory {
    static let volunteering = ActivityCategory(
        id: 1,
        name: "Волонтёрство",
        shortDescription: "Помогаем людям и городу",
        iconSystemName: "hands.sparkles"
    )

    static let sport = ActivityCategory(
        id: 2,
        name: "Спорт",
        shortDescription: "Соревнования и тренировки",
        iconSystemName: "sportscourt"
    )

    static let culture = ActivityCategory(
        id: 3,
        name: "Культура",
        shortDescription: "Концерты, театр, выставки",
        iconSystemName: "theatermasks"
    )

    static let science = ActivityCategory(
        id: 4,
        name: "Наука",
        shortDescription: "Хакатоны, конференции",
        iconSystemName: "atom"
    )

    nonisolated(unsafe) static let previewCategories: [ActivityCategory] = [
        .volunteering,
        .sport,
        .culture,
        .science
    ]
}
