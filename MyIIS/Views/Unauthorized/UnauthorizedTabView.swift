import SwiftUI

enum UnauthorizedAppTab: String, CaseIterable, Identifiable {
    case schedule
    case rating
    case services

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .schedule: return "calendar"
        case .rating: return "chart.bar.fill"
        case .services: return "square.grid.2x2.fill"
        }
    }

    var title: String {
        switch self {
        case .schedule: return NSLocalizedString("tab_schedule", comment: "")
        case .rating: return NSLocalizedString("unauthorized_rating_title", comment: "")
        case .services: return NSLocalizedString("tab_services", comment: "")
        }
    }
}

struct UnauthorizedTabView: View {
    @State private var selectedTab: UnauthorizedAppTab = .schedule

    var body: some View {
        if #available(iOS 18.0, *) {
            baseTabView
                .tabViewStyle(.sidebarAdaptable)
        } else {
            baseTabView
        }
    }

    private var baseTabView: some View {
        TabView(selection: $selectedTab) {
            ScheduleServiceView()
                .tag(UnauthorizedAppTab.schedule)
                .tabItem { Label(UnauthorizedAppTab.schedule.title, systemImage: UnauthorizedAppTab.schedule.icon) }

            UnauthorizedRatingView()
                .tag(UnauthorizedAppTab.rating)
                .tabItem { Label(UnauthorizedAppTab.rating.title, systemImage: UnauthorizedAppTab.rating.icon) }

            OthersTabView()
                .tag(UnauthorizedAppTab.services)
                .tabItem { Label(UnauthorizedAppTab.services.title, systemImage: UnauthorizedAppTab.services.icon) }
        }
        .automaticTabBarAppearance()
        .appBackground()
        .reduceMotionSensitive()
    }
}
