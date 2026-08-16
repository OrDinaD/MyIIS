import SwiftUI

struct AppSceneCommands: Commands {
    @ObservedObject private var router = AppRouter.shared

    var body: some Commands {
        SidebarCommands()

        CommandMenu("Навигация") {
            tabButton(for: .schedule, key: "1")

            if AppRouter.isSectionOrTabEnabled(AppTab.attendance.rawValue) {
                tabButton(for: .attendance, key: "2")
            }

            if AppRouter.isSectionOrTabEnabled(AppTab.rating.rawValue) {
                tabButton(for: .rating, key: "3")
            }

            if AppRouter.isSectionOrTabEnabled(AppTab.profile.rawValue) {
                tabButton(for: .profile, key: "4")
            }

            if AppRouter.isSectionOrTabEnabled(AppTab.home.rawValue) {
                tabButton(for: .home, key: "5")
            }

            tabButton(for: .others, key: "0")
        }
    }

    @ViewBuilder
    private func tabButton(for tab: AppTab, key: KeyEquivalent) -> some View {
        Button(tab.title) {
            router.selectedTab = tab
        }
        .keyboardShortcut(key, modifiers: .command)
    }
}
