//
//  MainTabView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .rating
    @State private var isMenuOpen = false
    @State private var selectedMenuItem: MenuItem?
    
    var body: some View {
        ZStack {
            // Основной TabView
            TabView(selection: $selectedTab) {
                RatingView()
                    .tag(Tab.rating)
                    .tabItem {
                        Label("Рейтинг", systemImage: "chart.bar.fill")
                    }
                
                AttendanceView()
                    .tag(Tab.attendance)
                    .tabItem {
                        Label("Пропуски", systemImage: "calendar.badge.clock")
                    }
                
                ProfileView()
                    .tag(Tab.profile)
                    .tabItem {
                        Label("Профиль", systemImage: "person.crop.circle.fill")
                    }
            }
            .tint(.blue)
            
            // Оверлей с затемнением при открытом меню
            if isMenuOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMenuOpen = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // Кнопка меню
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MenuButton(
                        isMenuOpen: $isMenuOpen,
                        selectedMenuItem: $selectedMenuItem
                    )
                    .padding(.trailing, 20)
                    .padding(.bottom, 90)
                }
            }
        }
        .sheet(item: $selectedMenuItem) { item in
            menuItemView(for: item)
        }
    }
    
    @ViewBuilder
    private func menuItemView(for item: MenuItem) -> some View {
        switch item {
        case .gradebook:
            GradebookView()
        case .study:
            StudyView()
        case .group:
            GroupView()
        case .library:
            LibraryView()
        case .announcements:
            AnnouncementsView()
        case .diploma:
            DiplomaView()
        case .dormitory:
            DormitoryView()
        case .penalties:
            PenaltiesView()
        case .activities:
            ActivitiesView()
        case .settings:
            SettingsView()
        }
    }
}

enum Tab {
    case rating
    case attendance
    case profile
}

#Preview {
    MainTabView()
}
