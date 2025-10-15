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
            // Основной контент
            TabView(selection: $selectedTab) {
                RatingView()
                    .tag(Tab.rating)
                
                AttendanceView()
                    .tag(Tab.attendance)
                
                ProfileView()
                    .tag(Tab.profile)
            }
            .toolbar(.hidden, for: .tabBar)
            
            // Оверлей с затемнением при открытом меню - адаптивный
            if isMenuOpen {
                Color.adaptiveShadow(opacity: 0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isMenuOpen = false
                        }
                    }
                    .transition(.opacity)
            }
            
            // Кастомный Tab Bar с кнопкой меню
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    // Компактный Tab Bar слева
                    CustomTabBar(selectedTab: $selectedTab)
                        .frame(maxWidth: 200)
                    
                    Spacer()
                    
                    // Кнопка меню справа на одном уровне
                    MenuButton(
                        isMenuOpen: $isMenuOpen,
                        selectedMenuItem: $selectedMenuItem
                    )
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
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
    
    var icon: String {
        switch self {
        case .rating: return "chart.bar.fill"
        case .attendance: return "calendar.badge.clock"
        case .profile: return "person.crop.circle.fill"
        }
    }
    
    var title: String {
        switch self {
        case .rating: return "Рейтинг"
        case .attendance: return "Пропуски"
        case .profile: return "Профиль"
        }
    }
}

// Кастомный компактный Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(tab: .rating, selectedTab: $selectedTab, animation: animation)
            TabBarButton(tab: .attendance, selectedTab: $selectedTab, animation: animation)
            TabBarButton(tab: .profile, selectedTab: $selectedTab, animation: animation)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        }
    }
}

// Кнопка Tab Bar
struct TabBarButton: View {
    let tab: Tab
    @Binding var selectedTab: Tab
    let animation: Namespace.ID
    
    var isSelected: Bool {
        selectedTab == tab
    }
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .frame(height: 16)
                
                Text(tab.title)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .padding(.horizontal, 4)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.blue.opacity(0.12))
                        .matchedGeometryEffect(id: "TAB_BACKGROUND", in: animation)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
}
