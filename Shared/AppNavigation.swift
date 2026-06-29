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
}

@MainActor
class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab
    @Published var servicesPath: NavigationPath

    static let shared = AppRouter()

    private init() {
        let initialState = AppRouter.initialState()
        self.selectedTab = initialState.tab
        self.servicesPath = initialState.path
    }

    static func isSectionOrTabEnabled(_ rawValue: String) -> Bool {
        let isBeta = UserDefaults.standard.bool(forKey: "enable_beta_sections")
        switch rawValue {
        case "home", "lms", "headman":
            return isBeta
        case "schedule":
            return true
        case "profile":
            return UserDefaults.standard.object(forKey: "show_tab_profile") == nil ? true : UserDefaults.standard.bool(forKey: "show_tab_profile")
        case "attendance":
            return UserDefaults.standard.object(forKey: "show_tab_attendance") == nil ? true : UserDefaults.standard.bool(forKey: "show_tab_attendance")
        case "rating":
            return UserDefaults.standard.object(forKey: "show_tab_rating") == nil ? true : UserDefaults.standard.bool(forKey: "show_tab_rating")
        default:
            return true
        }
    }

    private static func initialState() -> (tab: AppTab, path: NavigationPath) {
        let initialRaw = UserDefaults.standard.string(forKey: "initial_startup_tab") ?? "profile"

        guard isSectionOrTabEnabled(initialRaw) else {
            return (.others, NavigationPath()) // Fallback
        }

        var path = NavigationPath()
        let tab: AppTab

        if let section = AppSection(rawValue: initialRaw) {
            switch section {
            case .home: tab = .home
            case .profile: tab = .profile
            case .attendance: tab = .attendance
            case .rating: tab = .rating
            case .services: tab = .others
            case .gradebook, .study, .diploma, .group, .headman, .dormitory, .library, .lms, .schedule, .disciplines, .studyWeeks, .departments, .directory:
                tab = .others
                path.append(section)
            }
        } else if let rawTab = AppTab(rawValue: initialRaw) {
            tab = rawTab
        } else {
            tab = .profile
        }

        return (tab, path)
    }

    func navigate(to section: AppSection) {
        // Reset sub-navigation
        servicesPath = NavigationPath()

        switch section {
        case .home:
            selectedTab = .home
        case .profile:
            selectedTab = .profile
        case .attendance:
            selectedTab = .attendance
        case .rating:
            selectedTab = .rating
        case .services:
            selectedTab = .others
        case .gradebook, .study, .diploma, .group, .headman, .dormitory, .library, .lms, .schedule, .disciplines, .studyWeeks, .departments, .directory:
            selectedTab = .others
            servicesPath.append(section)
        }
    }

    func resetForLogout() {
        selectedTab = .profile
        servicesPath = NavigationPath()
    }

    func handleURL(_ url: URL) {
        guard url.scheme == "myiis" else { return }

        let path = url.path.replacingOccurrences(of: "/", with: "")
        if let section = AppSection(rawValue: path) {
            navigate(to: section)
        } else if url.host == "section", let section = AppSection(rawValue: url.lastPathComponent) {
            navigate(to: section)
        }
    }
}
