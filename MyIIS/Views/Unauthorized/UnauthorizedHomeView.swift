import SwiftUI

struct UnauthorizedHomeView: View {
    @State private var showLogin = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerIcon
                    welcomeCard
                    featuresSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Главная")
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
            .hiddenNavigationBarBackground()
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
        }
    }
    
    private var headerIcon: some View {
        Image(systemName: "graduationcap.circle.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 120, height: 120)
            .foregroundStyle(Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.15))
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
    
    private var welcomeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Добро пожаловать!")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("Интегрированная информационная система (ИИС) «БГУИР: Университет» предоставляет удобный доступ ко всем необходимым образовательным сервисам.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                
                Button {
                    showLogin = true
                } label: {
                    Text("Войти в аккаунт")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Возможности ИИС")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.leading, 8)
            
            VStack(spacing: 12) {
                featureRow(
                    icon: "list.bullet.rectangle.portrait",
                    title: "Расписание и Успеваемость",
                    description: "Следите за занятиями и оценками в реальном времени.",
                    color: .blue
                )
                featureRow(
                    icon: "doc.text.fill",
                    title: "Электронная зачетка",
                    description: "Все результаты сессий, зачеты и экзамены всегда под рукой.",
                    color: .green
                )
                featureRow(
                    icon: "building.2.fill",
                    title: "Справочник и Подразделения",
                    description: "Быстрый поиск контактов преподавателей и кафедр.",
                    color: .orange
                )
            }
        }
    }
    
    private func featureRow(icon: String, title: String, description: String, color: Color) -> some View {
        GlassCard {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
    }
}
