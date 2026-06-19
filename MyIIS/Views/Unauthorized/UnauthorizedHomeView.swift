import SwiftUI

struct UnauthorizedHomeView: View {
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            List {
                signInSection
                publicSections
                accountSections
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Главная")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
    }

    private var signInSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Color.accentColor, in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("БГУИР ИИС")
                            .font(.title3.weight(.semibold))
                        Text("Гостевой доступ")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Войдите, чтобы открыть личное расписание, зачётку, группу и остальные сервисы студента.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    showLogin = true
                } label: {
                    Label("Войти в аккаунт", systemImage: "person.crop.circle.badge.checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.vertical, 8)
        }
    }

    private var publicSections: some View {
        Section("Доступно без входа") {
            NavigationLink {
                UnauthorizedRatingView()
            } label: {
                HomeServiceRow(
                    icon: "chart.bar.fill",
                    tint: .blue,
                    title: "Рейтинг группы",
                    subtitle: "Факультет, специальность, курс и детали по студентам"
                )
            }

            NavigationLink {
                UnauthorizedDisciplinesView()
            } label: {
                HomeServiceRow(
                    icon: "list.bullet.rectangle.portrait.fill",
                    tint: .indigo,
                    title: "Список дисциплин",
                    subtitle: "Учебные планы по специальности и курсу"
                )
            }

            NavigationLink {
                UnauthorizedStudyWeeksView()
            } label: {
                HomeServiceRow(
                    icon: "calendar.day.timeline.left",
                    tint: .orange,
                    title: "Учебные недели",
                    subtitle: "Текущая неделя и календарь семестра"
                )
            }

            NavigationLink {
                UnauthorizedDirectoryView()
            } label: {
                HomeServiceRow(
                    icon: "book.closed.fill",
                    tint: .green,
                    title: "Справочник",
                    subtitle: "Контакты сотрудников и подразделений"
                )
            }
        }
    }

    private var accountSections: some View {
        Section("После входа") {
            lockedRow(icon: "calendar", title: "Личное расписание")
            lockedRow(icon: "book.closed.fill", title: "Электронная зачётка")
            lockedRow(icon: "person.3.fill", title: "Моя группа")
        }
    }

    private func lockedRow(icon: String, title: String) -> some View {
        Button {
            showLogin = true
        } label: {
            HStack(spacing: 12) {
                HomeIcon(icon: icon, tint: .secondary)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "lock.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Требуется вход в аккаунт")
    }
}

private struct HomeServiceRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HomeIcon(icon: icon, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HomeIcon: View {
    let icon: String
    let tint: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}
