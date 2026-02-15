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
            
            // Кастомный парящий TabBar
            CustomTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 10) // Отступ от самого низа экрана
        }
        .appBackground()
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

#Preview {
    MainTabView()
}
