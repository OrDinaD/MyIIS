//
//  MainTabView.swift
//  MyIIS
//
import SwiftUI

struct MainTabView: View {
    @ObservedObject private var router = AppRouter.shared
    @AppStorage("enable_beta_sections") private var enableBetaSections = false
    @AppStorage("show_tab_profile") private var showProfile = true
    @AppStorage("show_tab_attendance") private var showAttendance = true
    @AppStorage("show_tab_rating") private var showRating = true

    var body: some View {
        configuredTabView
            .automaticTabBarAppearance()
            .appBackground()
            .reduceMotionSensitive()
    }

    @ViewBuilder
    private var configuredTabView: some View {
        if #available(iOS 18.0, *) {
            baseTabView
                .tabViewStyle(.sidebarAdaptable)
        } else {
            baseTabView
        }
    }

    private var baseTabView: some View {
        TabView(selection: Binding(
            get: { router.selectedTab },
            set: { newTab in
                if newTab == router.selectedTab && newTab == .others {
                    router.servicesPath = NavigationPath()
                }
                router.selectedTab = newTab
            }
        )) {
            if enableBetaSections {
                SEOHomeView()
                    .tag(AppTab.home)
                    .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.icon) }
            }

            if showProfile {
                ProfileView()
                    .tag(AppTab.profile)
                    .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.icon) }
            }

            if showAttendance {
                AttendanceView()
                    .tag(AppTab.attendance)
                    .tabItem { Label(AppTab.attendance.title, systemImage: AppTab.attendance.icon) }
            }

            if showRating {
                RatingView()
                    .tag(AppTab.rating)
                    .tabItem { Label(AppTab.rating.title, systemImage: AppTab.rating.icon) }
            }

            OthersTabView()
                .tag(AppTab.others)
                .tabItem { Label(AppTab.others.title, systemImage: AppTab.others.icon) }
        }
    }
}

#Preview {
    MainTabView()
}
