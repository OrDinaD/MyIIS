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

    var body: some View {
        ZStack(alignment: .bottom) {
            // Фон приложения должен быть в самом низу
            // Но ProfileView и другие уже имеют свой фон, поэтому убедимся, что они прозрачные или используют общий
            
            TabView(selection: $selectedTab) {
                ProfileView()
                    .tag(Tab.profile)
                    .toolbar(.hidden, for: .tabBar)

                AttendanceView()
                    .tag(Tab.attendance)
                    .toolbar(.hidden, for: .tabBar)

                RatingView()
                    .tag(Tab.rating)
                    .toolbar(.hidden, for: .tabBar)

                OthersTabView()
                    .tag(Tab.others)
                    .toolbar(.hidden, for: .tabBar)
            }
            .ignoresSafeArea() // Позволяем контенту заходить под таб-бар
            
            // Кастомный парящий TabBar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .appBackground()
    }
}

#Preview {
    MainTabView()
}
