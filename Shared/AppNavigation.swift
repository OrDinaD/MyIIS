//
//  AppNavigation.swift
//  MyIIS
//
import Combine
import SwiftUI

enum AppSection: String, CaseIterable, Hashable {
    case home
    case profile
    case attendance
    case rating
    case services

    // Sub-services
    case gradebook
    case study
    case diploma
    case group
    case headman
    case dormitory
    case library
    case lms
    case schedule
    case disciplines
    case studyWeeks
    case departments
    case directory
    case support
}

/// Transfers navigation requests from the App Intents extension to the app
/// without relying on shared in-process state.
enum AppIntentNavigationStore {
    private static let pendingSectionKey = "app_intent_pending_section"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.identifier)
    }

    static func stage(_ section: AppSection) {
        defaults?.set(section.rawValue, forKey: pendingSectionKey)
    }

    static func takePendingSection() -> AppSection? {
        guard let rawValue = defaults?.string(forKey: pendingSectionKey) else {
            return nil
        }

        defaults?.removeObject(forKey: pendingSectionKey)
        return AppSection(rawValue: rawValue)
    }
}

@MainActor
class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab
    @Published var servicesPath: NavigationPath

    static let shared = AppRouter()
    private static let startupTabKey = "initial_startup_tab"
    private static let startupMigrationKey = "initial_startup_tab_migration_v2"

    private init() {
        Self.performStartupMigrationIfNeeded()
        let initialState = AppRouter.initialState()
        self.selectedTab = initialState.tab
        self.servicesPath = initialState.path
    }

    static func performStartupMigrationIfNeeded() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: startupMigrationKey) {
            defaults.set(true, forKey: startupMigrationKey)
            let existing = defaults.string(forKey: startupTabKey)
            if existing == nil || existing == "profile" || existing == "home" {
                defaults.set("schedule", forKey: startupTabKey)
            }
        }
    }

    static func isSectionOrTabEnabled(_ rawValue: String) -> Bool {
        let isBeta = UserDefaults.standard.bool(forKey: "enable_beta_sections")
        switch rawValue {
        case "schedule":
            return true
        case "services", "others":
            return true
        case "home", "lms", "headman":
            return isBeta
        case "profile":
            return UserDefaults.standard.bool(forKey: "show_tab_profile")
        case "attendance":
            return UserDefaults.standard.object(forKey: "show_tab_attendance") == nil ? true : UserDefaults.standard.bool(forKey: "show_tab_attendance")
        case "rating":
            return UserDefaults.standard.object(forKey: "show_tab_rating") == nil ? true : UserDefaults.standard.bool(forKey: "show_tab_rating")
        default:
            return true
        }
    }

    private static func initialState() -> (tab: AppTab, path: NavigationPath) {
        performStartupMigrationIfNeeded()
        let initialRaw = UserDefaults.standard.string(forKey: startupTabKey) ?? "schedule"

        guard isSectionOrTabEnabled(initialRaw) else {
            return (.schedule, NavigationPath())
        }

        var path = NavigationPath()
        let tab: AppTab

        if let section = AppSection(rawValue: initialRaw) {
            switch section {
            case .schedule:
                tab = .schedule
            case .home:
                tab = .home
            case .profile:
                tab = isSectionOrTabEnabled("profile") ? .profile : .schedule
            case .attendance:
                tab = .attendance
            case .rating:
                tab = .rating
            case .services:
                tab = .others
            case .gradebook, .study, .diploma, .group, .headman, .dormitory,
                 .library, .lms, .disciplines, .studyWeeks,
                 .departments, .directory, .support:
                tab = .others
                path.append(section)
            }
        } else if let rawTab = AppTab(rawValue: initialRaw) {
            tab = rawTab
        } else {
            tab = .schedule
        }

        return (tab, path)
    }

    func navigate(to section: AppSection) {
        // Reset sub-navigation
        servicesPath = NavigationPath()

        switch section {
        case .schedule:
            selectedTab = .schedule
        case .home:
            selectedTab = Self.isSectionOrTabEnabled("home") ? .home : .others
        case .profile:
            if Self.isSectionOrTabEnabled("profile") {
                selectedTab = .profile
            } else {
                selectedTab = .others
            }
        case .attendance:
            selectedTab = .attendance
        case .rating:
            selectedTab = .rating
        case .services:
            selectedTab = .others
        case .gradebook, .study, .diploma, .group, .headman, .dormitory, .library, .lms, .disciplines, .studyWeeks, .departments, .directory, .support:
            selectedTab = .others
            servicesPath.append(section)
        }
    }

    func resetForLogout() {
        selectedTab = .schedule
        servicesPath = NavigationPath()
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "myiis" else { return }

        let path = url.path.replacingOccurrences(of: "/", with: "")
        if let section = AppSection(rawValue: path) {
            navigate(to: section)
        } else if url.host == "section", let section = AppSection(rawValue: url.lastPathComponent) {
            navigate(to: section)
        } else if let host = url.host, let section = AppSection(rawValue: host) {
            navigate(to: section)
        }
    }
}
