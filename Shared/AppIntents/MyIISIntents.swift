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

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "intent_section_type"

    static let caseDisplayRepresentations: [SectionAppEnum: DisplayRepresentation] = [
        .profile: "intent_section_profile",
        .attendance: "intent_section_attendance",
        .rating: "intent_section_rating",
        .services: "intent_section_services",
        .gradebook: "intent_section_gradebook",
        .study: "intent_section_study",
        .diploma: "intent_section_diploma",
        .group: "intent_section_group",
        .headman: "intent_section_headman",
        .dormitory: "intent_section_dormitory",
        .library: "intent_section_library",
        .schedule: "intent_section_schedule"
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
    static let title: LocalizedStringResource = "intent_open_section_title"
    static let openAppWhenRun = true

    @Parameter(title: "intent_section_parameter")
    var section: SectionAppEnum

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentNavigationStore.stage(section.appSection)
        return .result()
    }
}

struct ShowAverageScoreIntent: AppIntent {
    static let title: LocalizedStringResource = "intent_average_title"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let data = MyIISDataStore.loadData()

        guard let score = data?.averageScore else {
            return .result(
                value: NSLocalizedString("intent_average_unavailable_short", comment: ""),
                dialog: IntentDialog(stringLiteral: NSLocalizedString("intent_average_unavailable_dialog", comment: ""))
            )
        }

        let formattedScore = String(format: "%.2f", score).replacingOccurrences(of: ".", with: ",")
        let response = String(
            format: NSLocalizedString("intent_average_response_format", comment: ""),
            formattedScore
        )

        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}

struct ShowAbsencesIntent: AppIntent {
    static let title: LocalizedStringResource = "intent_absences_title"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let data = MyIISDataStore.loadData()

        guard let hours = data?.unexcusedAbsences else {
            return .result(
                value: NSLocalizedString("intent_absences_unavailable_short", comment: ""),
                dialog: IntentDialog(stringLiteral: NSLocalizedString("intent_absences_unavailable_dialog", comment: ""))
            )
        }

        let response = String(
            format: NSLocalizedString("intent_absences_response_format", comment: ""),
            hours
        )
        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}

struct ShowGroupIntent: AppIntent {
    static let title: LocalizedStringResource = "intent_group_title"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let data = MyIISDataStore.loadData()

        guard let group = data?.userGroup else {
            return .result(
                value: NSLocalizedString("intent_group_unavailable_short", comment: ""),
                dialog: IntentDialog(stringLiteral: NSLocalizedString("intent_group_unavailable_dialog", comment: ""))
            )
        }

        let response = String(
            format: NSLocalizedString("intent_group_response_format", comment: ""),
            group
        )
        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}
