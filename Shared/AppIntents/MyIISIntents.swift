//
//  MyIISIntents.swift
//  MyIIS
//
import AppIntents
import SwiftUI

// MARK: - Enums

enum SectionAppEnum: String, AppEnum {
    case profile
    case attendance
    case rating
    case services
    case gradebook
    case study
    case diploma
    case group
    case headman
    case dormitory
    case library
    case schedule

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Раздел MyIIS"

    static let caseDisplayRepresentations: [SectionAppEnum: DisplayRepresentation] = [
        .profile: "Профиль",
        .attendance: "Пропуски",
        .rating: "Рейтинг",
        .services: "Сервисы",
        .gradebook: "Зачётка",
        .study: "Учёба",
        .diploma: "Диплом",
        .group: "Группа",
        .headman: "Староста",
        .dormitory: "Общежитие",
        .library: "Библиотека",
        .schedule: "Расписание"
    ]

    var appSection: AppSection {
        switch self {
        case .profile: return .profile
        case .attendance: return .attendance
        case .rating: return .rating
        case .services: return .services
        case .gradebook: return .gradebook
        case .study: return .study
        case .diploma: return .diploma
        case .group: return .group
        case .headman: return .headman
        case .dormitory: return .dormitory
        case .library: return .library
        case .schedule: return .schedule
        }
    }
}

// MARK: - Intents

struct OpenMyIISSectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Открыть раздел в MyIIS"
    static let openAppWhenRun = true

    @Parameter(title: "Раздел")
    var section: SectionAppEnum

    @MainActor
    func perform() async throws -> some IntentResult {
        // This will be handled in the app target
        AppRouter.shared.navigate(to: section.appSection)
        return .result()
    }
}

struct ShowAverageScoreIntent: AppIntent {
    static let title: LocalizedStringResource = "Показать средний балл"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let data = MyIISDataStore.loadData()

        guard let score = data?.averageScore else {
            return .result(
                value: "Не удалось получить средний балл.",
                dialog: "Не удалось получить средний балл. Сначала откройте MyIIS и обновите данные."
            )
        }

        let formattedScore = String(format: "%.2f", score).replacingOccurrences(of: ".", with: ",")
        let response = "Средний балл — \(formattedScore)"

        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}

struct ShowAbsencesIntent: AppIntent {
    static let title: LocalizedStringResource = "Показать пропуски"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let data = MyIISDataStore.loadData()

        guard let hours = data?.unexcusedAbsences else {
            return .result(
                value: "Не удалось получить данные о пропусках.",
                dialog: "Не удалось получить данные о пропусках. Сначала откройте MyIIS и обновите данные."
            )
        }

        let response = "Пропуски по неуважительной причине — \(hours) ч."
        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}

struct ShowGroupIntent: AppIntent {
    static let title: LocalizedStringResource = "Показать мою группу"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let data = MyIISDataStore.loadData()

        guard let group = data?.userGroup else {
            return .result(
                value: "Номер группы не найден.",
                dialog: "Номер группы не найден. Пожалуйста, авторизуйтесь в приложении."
            )
        }

        let response = "Ваша группа — \(group)"
        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}
