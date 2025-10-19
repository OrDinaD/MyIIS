//
//  MainTabView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var selectedTab: Tab = .profile

    init() {
        Self.configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ProfileView()
                .tag(Tab.profile)
                .tabItem {
                    Label(Tab.profile.title, systemImage: Tab.profile.icon)
                }

            AttendanceView()
                .tag(Tab.attendance)
                .tabItem {
                    Label(Tab.attendance.title, systemImage: Tab.attendance.icon)
                }

            RatingView()
                .tag(Tab.rating)
                .tabItem {
                    Label(Tab.rating.title, systemImage: Tab.rating.icon)
                }

            OthersTabView()
                .tag(Tab.others)
                .tabItem {
                    Label(Tab.others.title, systemImage: Tab.others.icon)
                }
        }
        .tint(Color.accentPurple)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

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
        case .others: return "Остальные"
        }
    }
}

private extension MainTabView {
    private static var didConfigureAppearance = false

    static func configureTabBarAppearance() {
        guard !didConfigureAppearance else { return }

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(Color.black.opacity(0.4))
                : UIColor(Color.white.opacity(0.55))
        }
        appearance.shadowColor = UIColor(Color.white.opacity(0.12))

        let selectedColor = UIColor(Color.accentPurple)
        let normalColor = UIColor.secondaryLabel

        [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ].forEach { layout in
            layout.normal.iconColor = normalColor
            layout.normal.titleTextAttributes = [
                .foregroundColor: normalColor
            ]

            layout.selected.iconColor = selectedColor
            layout.selected.titleTextAttributes = [
                .foregroundColor: selectedColor
            ]

            layout.focused.iconColor = selectedColor
            layout.focused.titleTextAttributes = [
                .foregroundColor: selectedColor
            ]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        didConfigureAppearance = true
    }
}

#Preview {
    MainTabView()
}
