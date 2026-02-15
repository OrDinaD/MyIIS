//
//  Tab.swift
//  MyIIS
//
//  Created by GitHub Copilot on 15.10.25.
//

import Foundation

enum Tab: String, CaseIterable, Identifiable {
    case profile
    case attendance
    case rating
    case others

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .profile: return "person.crop.circle.fill"
        case .attendance: return "calendar.badge.clock"
        case .rating: return "chart.bar.fill"
        case .others: return "square.grid.2x2.fill"
        }
    }

    var title: String {
        switch self {
        case .profile: return "Профиль"
        case .attendance: return "Пропуски"
        case .rating: return "Рейтинг"
        case .others: return "Сервисы"
        }
    }
}
