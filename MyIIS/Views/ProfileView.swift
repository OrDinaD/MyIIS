//
//  ProfileView.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showContacts = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Liquid Glass Background - Адаптивный для Dark Mode
                LinearGradient(
                    colors: Color.gradientBackground,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                if let user = viewModel.user {
                    ScrollView {
                        VStack(spacing: 24) {
                            // MARK: - Header with Photo and Name
                            VStack(spacing: 16) {
                                // Avatar with Liquid Glass effect
                                AsyncImage(url: user.photoURL) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay {
                                            Circle()
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [
                                                            Color.glassHighlight,
                                                            Color.accentPurple.opacity(0.4),
                                                            Color.accentPurple.opacity(0.2),
                                                            Color.clear
                                                        ],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 3
                                                )
                                        }
                                        .liquidGlassShadow(color: .accentPurple, radius: 20)
                                } placeholder: {
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .overlay {
                                                Circle()
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.accentPurple.opacity(0.25),
                                                                Color.accentPurple.opacity(0.08)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                            }
                                            .overlay {
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [
                                                                Color.glassHighlight,
                                                                Color.accentPurple.opacity(0.3)
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 3
                                                    )
                                            }
                                            .frame(width: 120, height: 120)
                                        
                                        Text(user.initials)
                                            .font(.system(size: 48, weight: .semibold))
                                            .foregroundStyle(
                                                LinearGradient.iconGradient(.accentPurple)
                                            )
                                    }
                                    .liquidGlassShadow(color: .accentPurple, radius: 20)
                                }
                                
                                // Name and Rating
                                VStack(spacing: 8) {
                                    Text(user.fullName)
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                    
                                    // Рейтинг звездочками (если включено в настройках)
                                    if user.settings.isShowRating {
                                        HStack(spacing: 4) {
                                            ForEach(0..<5) { index in
                                                Image(systemName: "star.fill")
                                                    .foregroundStyle(index < user.rating ? Color.ratingYellow : Color.secondary.opacity(0.3))
                                                    .font(.system(size: 18))
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.top, 20)
                            
                            // MARK: - Contacts Section
                            if viewModel.user != nil {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        SectionHeader(title: "Контакты", icon: "envelope.fill")
                                        Spacer()
                                        // Кнопка показа/скрытия контактов
                                        Button {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                showContacts.toggle()
                                            }
                                        } label: {
                                            Image(systemName: showContacts ? "eye.fill" : "eye.slash.fill")
                                                .foregroundStyle(Color.accentPurple)
                                                .font(.system(size: 16, weight: .semibold))
                                                .frame(width: 32, height: 32)
                                                .background {
                                                    Circle()
                                                        .fill(.ultraThinMaterial)
                                                        .overlay {
                                                            Circle()
                                                                .fill(LinearGradient.glassOverlay)
                                                        }
                                                        .overlay {
                                                            Circle()
                                                                .stroke(
                                                                    LinearGradient(
                                                                        colors: [Color.glassHighlight, Color.accentPurple.opacity(0.2)],
                                                                        startPoint: .topLeading,
                                                                        endPoint: .bottomTrailing
                                                                    ),
                                                                    lineWidth: 1.5
                                                                )
                                                        }
                                                        .shadow(color: Color.accentPurple.opacity(0.15), radius: 8, x: 0, y: 4)
                                                }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    if showContacts {
                                        GlassCard {
                                            VStack(spacing: 12) {
                                                if let email = viewModel.user?.email, !email.isEmpty {
                                                    HStack {
                                                        Image(systemName: "envelope.fill")
                                                            .foregroundStyle(Color.accentPurple)
                                                            .frame(width: 20)
                                                        Text(email)
                                                            .font(.body)
                                                        Spacer()
                                                    }
                                                }
                                                
                                                if let phone = viewModel.user?.phone, !phone.isEmpty {
                                                    if viewModel.user?.email != nil {
                                                        Divider()
                                                    }
                                                    HStack {
                                                        Image(systemName: "phone.fill")
                                                            .foregroundStyle(Color.accentPurple)
                                                            .frame(width: 20)
                                                        Text(phone)
                                                            .font(.body)
                                                        Spacer()
                                                    }
                                                }
                                            }
                                            .padding()
                                        }
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .scale.combined(with: .opacity)
                                        ))
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // MARK: - Education Section
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Образование", icon: "graduationcap.fill")
                                
                                GlassCard {
                                    VStack(spacing: 12) {
                                        InfoRow(label: "Факультет", value: user.education.faculty)
                                        Divider()
                                        InfoRow(label: "Специальность", value: user.education.speciality)
                                        Divider()
                                        InfoRow(label: "Группа", value: user.education.group)
                                        Divider()
                                        InfoRow(label: "Курс", value: "\(user.education.course)")
                                    }
                                    .padding()
                                }
                            }
                            .padding(.horizontal)
                            
                            // MARK: - Personal Info Section (только если есть данные)
                            if user.summary != nil || user.birthDay != "Не указана" {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeader(title: "Личная информация", icon: "person.fill")
                                    
                                    GlassCard {
                                        VStack(spacing: 12) {
                                            // Показываем дату рождения только если она указана
                                            if user.birthDay != "Не указана" {
                                                InfoRow(label: "Дата рождения", value: formatDate(user.birthDay))
                                            }
                                            
                                            if let summary = user.summary {
                                                if user.birthDay != "Не указана" {
                                                    Divider()
                                                }
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("О себе")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                    Text(summary)
                                                        .font(.body)
                                                }
                                            }
                                        }
                                        .padding()
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // MARK: - Skills Section
                            if !user.skills.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeader(title: "Навыки", icon: "star.circle.fill")
                                    
                                    GlassCard {
                                        FlowLayout(spacing: 8) {
                                            ForEach(user.skills) { skill in
                                                SkillTag(name: skill.name)
                                            }
                                        }
                                        .padding()
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // MARK: - References Section
                            if !user.references.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    SectionHeader(title: "Ссылки", icon: "link.circle.fill")
                                    
                                    GlassCard {
                                        VStack(spacing: 8) {
                                            ForEach(user.references) { reference in
                                                Link(destination: URL(string: reference.reference) ?? URL(string: "https://bsuir.by")!) {
                                                    HStack {
                                                        Image(systemName: getIconForReference(reference.name))
                                                            .foregroundStyle(.purple)
                                                        Text(reference.name)
                                                            .foregroundStyle(.primary)
                                                        Spacer()
                                                        Image(systemName: "arrow.up.right")
                                                            .font(.caption)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                    .padding(.vertical, 8)
                                                }
                                                
                                                if reference.id != user.references.last?.id {
                                                    Divider()
                                                }
                                            }
                                        }
                                        .padding()
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // MARK: - Settings Section (READ-ONLY из API)
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(title: "Настройки профиля", icon: "gearshape.fill")
                                
                                GlassCard {
                                    VStack(spacing: 12) {
                                        SettingRow(
                                            icon: "eye.fill",
                                            label: "Публичный профиль",
                                            isEnabled: user.settings.isPublicProfile
                                        )
                                        Divider()
                                        SettingRow(
                                            icon: "briefcase.fill",
                                            label: "Ищу работу",
                                            isEnabled: user.settings.isSearchJob
                                        )
                                        Divider()
                                        SettingRow(
                                            icon: "star.fill",
                                            label: "Показывать рейтинг",
                                            isEnabled: user.settings.isShowRating
                                        )
                                        
                                        Divider()
                                        
                                        // Информационное сообщение
                                        HStack(spacing: 8) {
                                            Image(systemName: "info.circle.fill")
                                                .foregroundStyle(.secondary)
                                                .font(.system(size: 14))
                                            Text("Изменить настройки можно в веб-версии ИИС")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.top, 4)
                                    }
                                    .padding()
                                }
                            }
                            .padding(.horizontal)
                            
                            Spacer(minLength: 32)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Нет данных о пользователе")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if viewModel.user != nil {
                    Button {
                        viewModel.logout()
                    } label: {
                        Label {
                            Text("Выйти")
                                .font(.system(size: 15, weight: .semibold))
                        } icon: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(LinearGradient(
                            colors: [
                                Color.statusError,
                                Color.statusError.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.55),
                                                Color.statusError.opacity(0.2)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                                    .blendMode(.overlay)
                            }
                            .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
                    )
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        formatter.dateFormat = "d MMMM yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
    
    private func getIconForReference(_ name: String) -> String {
        switch name.lowercased() {
        case "vk", "vkontakte":
            return "person.2.fill"
        case "telegram", "tg":
            return "paperplane.fill"
        case "github":
            return "chevron.left.forwardslash.chevron.right"
        case "linkedin":
            return "briefcase.fill"
        case "instagram":
            return "camera.fill"
        default:
            return "link"
        }
    }
}

// MARK: - Supporting Views

struct QuickActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(LinearGradient.iconGradient(color))
                
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 90)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient.glassOverlay)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LinearGradient.glassBorder, lineWidth: 1.5)
                    }
                    .shadow(color: color.opacity(0.12), radius: 12, x: 0, y: 6)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentPurple)
            Text(title)
                .font(.headline)
        }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        // Верхний блик для Liquid Glass эффекта - адаптивный
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient.glassOverlay)
                    }
                    .overlay {
                        // Граница с адаптивным градиентом
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(LinearGradient.glassBorder, lineWidth: 1.5)
                    }
                    .cardShadow()
            }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

private struct SkillTag: View {
    let name: String
    
    var body: some View {
        Text(name)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.accentPurple)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentPurple.opacity(0.15),
                                        Color.accentPurple.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        Capsule()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.glassHighlight,
                                        Color.accentPurple.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .shadow(color: Color.accentPurple.opacity(0.08), radius: 6, x: 0, y: 3)
            }
    }
}

struct SettingRow: View {
    let icon: String
    let label: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(isEnabled ? Color.accentPurple : Color.secondary)
            Text(label)
                .font(.body)
            Spacer()
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isEnabled ? Color.statusSuccess : Color.statusError.opacity(0.6))
        }
    }
}

// MARK: - FlowLayout for Skills

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = AuthenticationService.shared
        authService.currentUser = User.mock
        
        return ProfileView()
            .environmentObject(authService)
    }
}
#endif
