import SwiftUI

struct UnauthorizedServicesView: View {
    @State private var showLogin = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showLogin = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "person.crop.circle.fill.badge.plus")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Войти в аккаунт")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Для доступа ко всем функциям")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Учеба") {
                    NavigationLink(destination: UnauthorizedDisciplinesView()) {
                        serviceRow(icon: "list.bullet.rectangle.portrait.fill", title: "Список дисциплин")
                    }
                    NavigationLink(destination: UnauthorizedStudyWeeksView()) {
                        serviceRow(icon: "calendar.day.timeline.left", title: "Учебные недели")
                    }
                }
                
                Section("Информация") {
                    NavigationLink(destination: UnauthorizedDepartmentsView()) {
                        serviceRow(icon: "building.2.fill", title: "Подразделения")
                    }
                    NavigationLink(destination: UnauthorizedDirectoryView()) {
                        serviceRow(icon: "book.closed.fill", title: "Справочник")
                    }
                }
                
                Section("Сервисы (требуется авторизация)") {
                    lockedServiceRow(icon: "book.closed.fill", title: "Электронная зачетка")
                    lockedServiceRow(icon: "calendar", title: "Расписание")
                    lockedServiceRow(icon: "graduationcap.fill", title: "Успеваемость")
                    lockedServiceRow(icon: "person.3.fill", title: "Моя группа")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Сервисы")
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
    }
    
    private func serviceRow(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                )
            
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
    
    private func lockedServiceRow(icon: String, title: String) -> some View {
        Button {
            showLogin = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.12))
                    )
                
                Text(title)
                    .font(.body.weight(.regular))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
