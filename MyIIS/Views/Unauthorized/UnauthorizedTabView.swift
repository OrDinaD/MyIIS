import SwiftUI

enum UnauthorizedAppTab: String, CaseIterable, Identifiable {
    case home
    case rating
    case services

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .rating: return "chart.bar.fill"
        case .services: return "square.grid.2x2.fill"
        }
    }

    var title: String {
        switch self {
        case .home: return NSLocalizedString("tab_home", comment: "")
        case .rating: return NSLocalizedString("unauthorized_rating_title", comment: "")
        case .services: return NSLocalizedString("tab_services", comment: "")
        }
    }
}

struct UnauthorizedTabView: View {
    @State private var selectedTab: UnauthorizedAppTab = .home

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
            UnauthorizedHomeView()
                .tag(UnauthorizedAppTab.home)
                .tabItem { Label(UnauthorizedAppTab.home.title, systemImage: UnauthorizedAppTab.home.icon) }

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
