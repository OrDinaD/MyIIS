import Foundation

extension LMSQuizService {
    struct HTMLResponse {
        let html: String
        let finalURL: URL
    }

    enum AttemptSubmitAction {
        case next
        case finishAttempt

        var buttonLabel: String {
            switch self {
            case .next:
                return "Следующая страница"
            case .finishAttempt:
                return "Закончить попытку..."
            }
        }

        func nextPageValue(current page: LMSQuizAttemptPage) -> String {
            switch self {
            case .next:
                return String(page.nextPage)
            case .finishAttempt:
                return "-1"
            }
        }
    }
}
