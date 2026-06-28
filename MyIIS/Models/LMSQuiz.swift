import Foundation

struct LMSQuizOverview {
    let title: String
    let courseTitle: String?
    let quizURL: URL
    let quizId: Int?
    let resumeAttemptURL: URL?
    let startForm: LMSQuizForm?
    let preflightForm: LMSQuizForm?
    let warningText: String?
    let previousAttempts: [LMSQuizPreviousAttempt]
}

struct LMSQuizForm {
    let actionURL: URL
    let method: String
    let fields: [String: String]
}

struct LMSQuizAttemptPage {
    let title: String
    let pageTitle: String?
    let actionURL: URL
    let cmid: Int?
    let attemptId: Int
    let sesskey: String
    let thisPage: Int
    let nextPage: Int
    let timeup: String
    let mdlscrollto: String
    let slots: String
    let questions: [LMSQuizQuestion]
    let navigation: [LMSQuizNavigationItem]
    let endAttemptURL: URL?
    let timerRemainingSeconds: Int?
}

struct LMSQuizQuestion: Identifiable {
    let id: String
    let number: String
    let state: String?
    let grade: String?
    let sequenceFieldName: String
    let sequenceValue: String
    let flaggedFieldName: String
    let flaggedValue: String
    let textHTML: String
    let textImages: [URL]
    let answerFieldName: String
    let selectedAnswer: String?
    let choices: [LMSQuizChoice]
}

struct LMSQuizChoice: Identifiable {
    let id: String
    let value: String
    let labelHTML: String
    let images: [URL]
}

struct LMSQuizNavigationItem: Identifiable {
    let id: Int
    let pageIndex: Int
    let label: String
    let state: String
    let isCurrent: Bool
    let url: URL?
}

struct LMSQuizSummaryPage {
    let title: String
    let courseTitle: String?
    let attemptId: Int
    let cmid: Int?
    let statusItems: [LMSQuizSummaryItem]
    let finishForm: LMSQuizForm?
    let returnForm: LMSQuizForm?
    let deadlineText: String?
}

struct LMSQuizSummaryItem: Identifiable {
    let id: Int
    let questionNumber: Int
    let status: String
    let url: URL?
}

struct LMSQuizPreviousAttempt: Identifiable {
    let id = UUID()
    let title: String
    let state: String?
    let startedAt: String?
    let finishedAt: String?
    let duration: String?
    let score: String?
    let grade: String?
    let reviewMessage: String?
}

enum LMSQuizScreenState {
    case overview(LMSQuizOverview)
    case attempt(LMSQuizAttemptPage)
    case summary(LMSQuizSummaryPage)
    case completion(String)
}

enum LMSQuizError: LocalizedError {
    case invalidQuizURL
    case missingStartForm
    case missingAttemptData
    case missingFinishForm
    case parseFailed

    var errorDescription: String? {
        switch self {
        case .invalidQuizURL:
            return "Невалидная ссылка на тест Moodle."
        case .missingStartForm:
            return "Не удалось найти форму старта попытки."
        case .missingAttemptData:
            return "Не удалось распознать данные текущей попытки."
        case .missingFinishForm:
            return "Не удалось распознать форму завершения теста."
        case .parseFailed:
            return "Не удалось обработать ответ сервера Moodle."
        }
    }
}
