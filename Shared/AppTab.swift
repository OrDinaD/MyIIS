//
//  Tab.swift
//  MyIIS
//
import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case schedule
    case home
    case profile
    case attendance
    case rating
    case others

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .schedule: return "calendar"
        case .home: return "house.fill"
        case .profile: return "person.crop.circle"
        case .attendance: return "calendar.badge.clock"
        case .rating: return "chart.bar"
        case .others: return "square.grid.2x2"
        }
    }

    var title: String {
        switch self {
        case .schedule: return NSLocalizedString("tab_schedule", comment: "")
        case .home: return "СЭО"
        case .profile: return NSLocalizedString("tab_profile", comment: "")
        case .attendance: return NSLocalizedString("tab_attendance", comment: "")
        case .rating: return NSLocalizedString("tab_rating", comment: "")
        case .others: return NSLocalizedString("tab_services", comment: "")
        }
    }
}
