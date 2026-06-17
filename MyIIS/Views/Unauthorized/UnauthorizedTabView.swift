import SwiftUI

enum UnauthorizedAppTab: String, CaseIterable, Identifiable {
    case home
    case departments
    case directory
    case rating
    case services
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .departments: return "building.2.fill"
        case .directory: return "book.closed.fill"
        case .rating: return "chart.bar.fill"
        case .services: return "square.grid.2x2.fill"
        }
    }
    
    var title: String {
        switch self {
        case .home: return "Главная"
        case .departments: return "Подразделения"
        case .directory: return "Справочник"
        case .rating: return "Рейтинг"
        case .services: return "Сервисы"
        }
    }
}

struct UnauthorizedTabView: View {
    @State private var selectedTab: UnauthorizedAppTab = .home
    
    var body: some View {
        TabView(selection: $selectedTab) {
            UnauthorizedHomeView()
                .tag(UnauthorizedAppTab.home)
                .tabItem { Label(UnauthorizedAppTab.home.title, systemImage: UnauthorizedAppTab.home.icon) }
                
            UnauthorizedDepartmentsView()
                .tag(UnauthorizedAppTab.departments)
                .tabItem { Label(UnauthorizedAppTab.departments.title, systemImage: UnauthorizedAppTab.departments.icon) }
                
            UnauthorizedDirectoryView()
                .tag(UnauthorizedAppTab.directory)
                .tabItem { Label(UnauthorizedAppTab.directory.title, systemImage: UnauthorizedAppTab.directory.icon) }
                
            UnauthorizedRatingView()
                .tag(UnauthorizedAppTab.rating)
                .tabItem { Label(UnauthorizedAppTab.rating.title, systemImage: UnauthorizedAppTab.rating.icon) }
                
            UnauthorizedServicesView()
                .tag(UnauthorizedAppTab.services)
                .tabItem { Label(UnauthorizedAppTab.services.title, systemImage: UnauthorizedAppTab.services.icon) }
        }
        .toolbarBackground(.regularMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .appBackground()
        .reduceMotionSensitive()
    }
}
