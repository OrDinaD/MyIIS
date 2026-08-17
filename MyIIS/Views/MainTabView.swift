//
//  MainTabView.swift
//  MyIIS
//
import SwiftUI

struct MainTabView: View {
    @ObservedObject private var router = AppRouter.shared
    @AppStorage("show_tab_profile") private var showProfile = false
    @AppStorage("show_tab_attendance") private var showAttendance = true
    @AppStorage("show_tab_rating") private var showRating = true

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                ModernMainTabView(
                    router: router,
                    showProfile: showProfile,
                    showAttendance: showAttendance,
                    showRating: showRating
                )
            } else {
                LegacyMainTabView(
                    router: router,
                    showProfile: showProfile,
                    showAttendance: showAttendance,
                    showRating: showRating
                )
            }
        }
        .automaticTabBarAppearance()
        .appBackground()
        .reduceMotionSensitive()
        .onChange(of: showAttendance) { _, newValue in
            if !newValue && router.selectedTab == .attendance {
                router.selectedTab = .schedule
            }
        }
        .onChange(of: showRating) { _, newValue in
            if !newValue && router.selectedTab == .rating {
                router.selectedTab = .schedule
            }
        }
        .onChange(of: showProfile) { _, newValue in
            if !newValue && router.selectedTab == .profile {
                router.selectedTab = .schedule
            }
        }
    }
}

@available(iOS 18.0, *)
private struct ModernMainTabView: View {
    @ObservedObject var router: AppRouter
    let showProfile: Bool
    let showAttendance: Bool
    let showRating: Bool
    @AppStorage("tabViewCustomization") private var tabCustomization: TabViewCustomization = TabViewCustomization()

    var body: some View {
        TabView(selection: tabBinding) {
            Tab(LocalizedStringKey("tab_schedule"), systemImage: AppTab.schedule.icon, value: AppTab.schedule) {
                NavigationStack {
                    ScheduleServiceView()
                }
            }
            .customizationID("tab.schedule")
            .customizationBehavior(.disabled, for: .sidebar, .tabBar)

            if showAttendance {
                Tab(LocalizedStringKey("tab_attendance"), systemImage: AppTab.attendance.icon, value: AppTab.attendance) {
                    AttendanceView()
                }
                .customizationID("tab.attendance")
            }

            if showRating {
                Tab(LocalizedStringKey("tab_rating"), systemImage: AppTab.rating.icon, value: AppTab.rating) {
                    RatingView()
                }
                .customizationID("tab.rating")
            }

            if showProfile {
                Tab(LocalizedStringKey("tab_profile"), systemImage: AppTab.profile.icon, value: AppTab.profile) {
                    ProfileView()
                }
                .customizationID("tab.profile")
            }

            Tab(LocalizedStringKey("tab_services"), systemImage: AppTab.others.icon, value: AppTab.others) {
                OthersTabView()
            }
            .customizationID("tab.others")
            .customizationBehavior(.disabled, for: .sidebar, .tabBar)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($tabCustomization)
    }

    private var tabBinding: Binding<AppTab> {
        Binding(
            get: { router.selectedTab },
            set: { newTab in
                if newTab == router.selectedTab && newTab == .others {
                    router.servicesPath = NavigationPath()
                }
                router.selectedTab = newTab
            }
        )
    }
}

private struct LegacyMainTabView: View {
    @ObservedObject var router: AppRouter
    let showProfile: Bool
    let showAttendance: Bool
    let showRating: Bool

    var body: some View {
        TabView(selection: tabBinding) {
            NavigationStack {
                ScheduleServiceView()
            }
                .tag(AppTab.schedule)
                .tabItem { Label(AppTab.schedule.title, systemImage: AppTab.schedule.icon) }

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

            if showProfile {
                ProfileView()
                    .tag(AppTab.profile)
                    .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.icon) }
            }

            OthersTabView()
                .tag(AppTab.others)
                .tabItem { Label(AppTab.others.title, systemImage: AppTab.others.icon) }
        }
    }

    private var tabBinding: Binding<AppTab> {
        Binding(
            get: { router.selectedTab },
            set: { newTab in
                if newTab == router.selectedTab && newTab == .others {
                    router.servicesPath = NavigationPath()
                }
                router.selectedTab = newTab
            }
        )
    }
}

#Preview {
    MainTabView()
}
