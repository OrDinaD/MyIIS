//
//  MyIISShortcuts.swift
//  MyIIS
//
import AppIntents

struct MyIISShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ShowAverageScoreIntent(),
            phrases: [
                "Покажи мой средний балл в \(.applicationName)",
                "Какой у меня средний балл в \(.applicationName)",
                "Средний балл в \(.applicationName)"
            ],
            shortTitle: "Средний балл",
            systemImageName: "graduationcap"
        )

        AppShortcut(
            intent: ShowAbsencesIntent(),
            phrases: [
                "Сколько у меня пропусков в \(.applicationName)",
                "Покажи мои пропуски в \(.applicationName)",
                "Пропуски в \(.applicationName)"
            ],
            shortTitle: "Пропуски",
            systemImageName: "calendar.badge.clock"
        )

        AppShortcut(
            intent: ShowGroupIntent(),
            phrases: [
                "Покажи мою группу в \(.applicationName)",
                "Какая у меня группа в \(.applicationName)",
                "Моя группа в \(.applicationName)"
            ],
            shortTitle: "Моя группа",
            systemImageName: "person.3"
        )

        AppShortcut(
            intent: OpenMyIISSectionIntent(),
            phrases: [
                "Открой \(\.$target) в \(.applicationName)",
                "Перейти в \(\.$target) в \(.applicationName)"
            ],
            shortTitle: "Открыть раздел",
            systemImageName: "arrow.up.right.square"
        )
    }
}
