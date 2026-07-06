import Foundation

struct LMSPageContent {
    let title: String
    let contentHTML: String
}

struct LMSFeedbackPage {
    let title: String
    let form: LMSFeedbackForm?
    let completionMessage: String?
}

struct LMSFeedbackForm {
    let actionURL: URL
    let method: String
    let fields: [String: String]
    let items: [LMSFeedbackItem]
    let submitName: String
    let submitValue: String
}

struct LMSFeedbackItem: Identifiable {
    let id: String
    let promptHTML: String
    let type: LMSFeedbackItemType
    let name: String?
    let options: [LMSFeedbackOption]
    let defaultValue: String?
    let isRequired: Bool
}

enum LMSFeedbackItemType {
    case label
    case select
    case singleChoice
    case multipleChoice
    case text
    case textarea
}

struct LMSFeedbackOption: Identifiable {
    let id: String
    let name: String
    let value: String
    let labelHTML: String
    let isSelected: Bool
}

enum LMSActivityContentError: LocalizedError {
    case missingContent
    case missingForm
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingContent:
            return "Не удалось найти содержимое материала."
        case .missingForm:
            return "Не удалось распознать форму анкеты."
        case .invalidResponse:
            return "СЭО вернул некорректный ответ."
        }
    }
}
