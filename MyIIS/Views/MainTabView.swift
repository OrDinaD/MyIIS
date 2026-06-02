//
//  MainTabView.swift
//  MyIIS
//
import SwiftUI
import UIKit

struct MainTabView: View {
    @StateObject private var router = AppRouter.shared
    @AppStorage("enable_beta_sections") private var enableBetaSections = false
    @AppStorage("show_tab_profile") private var showProfile = true
    @AppStorage("show_tab_attendance") private var showAttendance = true
    @AppStorage("show_tab_rating") private var showRating = true

    var body: some View {
        configuredTabView
            .toolbarBackground(.regularMaterial, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .appBackground()
    }

    @ViewBuilder
    private var configuredTabView: some View {
        if #available(iOS 18.0, *), shouldUseSidebarAdaptableStyle {
            baseTabView
                .tabViewStyle(.sidebarAdaptable)
        } else {
            baseTabView
        }
    }

    private var shouldUseSidebarAdaptableStyle: Bool {
        UIDevice.current.userInterfaceIdiom == .pad || ProcessInfo.processInfo.isiOSAppOnMac
    }

    private var baseTabView: some View {
        TabView(selection: $router.selectedTab) {
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
