//
//  OthersTabView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 09.11.25.
//

import SwiftUI

struct OthersTabView: View {
    @State private var navigationPath: [MenuItem] = []
    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 16, alignment: .top)
    ]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(MenuItem.allCases) { item in
                        NavigationLink(value: item) {
                            MenuItemCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(item.accessibilityLabel)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
            }
            .background(
                LinearGradient(
                    colors: Color.gradientBackground,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Остальные")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .navigationDestination(for: MenuItem.self) { item in
            item.destinationView
        }
    }
}

enum MenuItem: String, CaseIterable, Identifiable {
    case gradebook = "Зачетка"
    case study = "Учеба"
    case group = "Группа"
    case library = "Библиотека"
    case announcements = "Объявления"
    case diploma = "Диплом"
    case dormitory = "Общежитие"
    case penalties = "Взыскания"
    case activities = "Активности"
    case settings = "Настройки"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .gradebook: return "book.closed.fill"
        case .study: return "graduationcap.fill"
        case .group: return "person.3.fill"
        case .library: return "books.vertical.fill"
        case .announcements: return "megaphone.fill"
        case .diploma: return "doc.text.fill"
        case .dormitory: return "building.2.fill"
        case .penalties: return "exclamationmark.triangle.fill"
        case .activities: return "sparkles"
        case .settings: return "gearshape.fill"
        }
    }

    var tint: Color {
        switch self {
        case .gradebook: return .green
        case .study: return .indigo
        case .group: return .cyan
        case .library: return .brown
        case .announcements: return .red
        case .diploma: return .teal
        case .dormitory: return .mint
        case .penalties: return .yellow
        case .activities: return .pink
        case .settings: return .gray
        }
    }

    var description: String {
        switch self {
        case .gradebook: return "Оценки, зачётные книжки и средний балл."
        case .study: return "Учебный план, расписание и дисциплины."
        case .group: return "Состав группы и контактная информация."
        case .library: return "Каталог материалов и история выдач."
        case .announcements: return "Новости и важные уведомления университета."
        case .diploma: return "Статус диплома и ключевые этапы."
        case .dormitory: return "Данные об общежитии и заселении."
        case .penalties: return "История взысканий и дисциплина."
        case .activities: return "Внеучебные проекты и активности."
        case .settings: return "Профиль, безопасность и настройки приложения."
        }
    }

    var accessibilityLabel: String {
        "\(rawValue). \(description)"
    }

    @ViewBuilder
    var destinationView: some View {
        switch self {
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

private struct MenuItemCard: View {
    let item: MenuItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            iconBadge

            VStack(alignment: .leading, spacing: 6) {
                Text(item.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(item.description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(item.tint.opacity(0.9))
                    .padding(6)
                    .background(
                        Circle()
                            .fill(item.tint.opacity(0.12))
                    )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .background(glassBackground)
        .overlay(glassBorder)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.accentPurple.opacity(0.04), radius: 16, x: 0, y: 12)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 52, height: 52)
                .overlay {
                    Circle()
                        .fill(item.tint.opacity(0.18))
                        .blur(radius: 14)
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.glassHighlight,
                                    Color.glassOverlay,
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }

            Image(systemName: item.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(item.tint.gradient)
        }
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }

    private var glassBorder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.45),
                        Color.white.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.9
            )
    }
}

private extension Color {
    var gradient: LinearGradient {
        LinearGradient(
            colors: [
                self,
                self.opacity(0.7)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    OthersTabView()
}
