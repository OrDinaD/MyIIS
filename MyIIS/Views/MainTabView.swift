//
//  MainTabView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

enum MenuItem: Identifiable {
    case gradebook
    case study
    case group
    case library
    case announcements
    case diploma
    case dormitory
    case penalties
    case activities
    case settings

    var id: String { String(describing: self) }
}

struct MainTabView: View {
    @State private var selectedTab: Tab = .rating
    @State private var isMenuOpen = false
    @State private var selectedMenuItem: MenuItem?
    
    var body: some View {
        ZStack(alignment: .bottom) {
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
            .ignoresSafeArea(edges: .bottom)
            
            // Оверлей с затемнением при открытом меню - адаптивный
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
            
            // Кастомный Tab Bar с кнопкой меню
            TabBarContainer {
                HStack(spacing: 12) {
                    CustomTabBar(selectedTab: $selectedTab)
                    
                    MenuButton(
                        isMenuOpen: $isMenuOpen,
                        selectedMenuItem: $selectedMenuItem
                    )
                }
                .padding(.horizontal, 12)
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

enum Tab: Hashable {
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
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: isSelected ? 17 : 16, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(height: 18)
                
                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .matchedGeometryEffect(id: "TAB_BACKGROUND", in: animation)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct TabBarContainer<Content: View>: View {
    // Removed: @Environment(\.safeAreaInsets) private var insets
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Верхний разделитель
            Divider()
                .background(Color.black.opacity(0.08))
                .blendMode(.overlay)
            
            HStack { content }
                .frame(height: 56)
                .safeAreaPadding(.bottom, 0)
                .padding(.bottom, 8)
                .background {
                    // Стеклянный фон
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Rectangle().fill(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                        }
                        .overlay {
                            Rectangle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.35),
                                            .white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                        .shadow(color: .black.opacity(0.12), radius: 14, y: -2)
                }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    MainTabView()
}

