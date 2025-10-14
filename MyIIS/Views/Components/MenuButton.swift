//
//  MenuButton.swift
//  MyIIS
//
//  Created by GitHub Copilot on 13.10.25.
//

import SwiftUI

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
}

struct MenuButton: View {
    @Binding var isMenuOpen: Bool
    @Binding var selectedMenuItem: MenuItem?
    
    var body: some View {
        ZStack {
            // Кнопка меню
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    isMenuOpen.toggle()
                }
            } label: {
                ZStack {
                    // Liquid Glass эффект
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 56, height: 56)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .white.opacity(0.3),
                                            .white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        }
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    
                    Image(systemName: isMenuOpen ? "xmark" : "ellipsis")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                        .rotationEffect(.degrees(isMenuOpen ? 0 : 90))
                }
            }
            
            // Выпадающее меню
            if isMenuOpen {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 70)
                    
                    VStack(spacing: 12) {
                        MenuItemView(
                            icon: "book.closed.fill",
                            title: "Зачетка",
                            color: .green,
                            isSelected: selectedMenuItem == .gradebook
                        ) {
                            selectMenuItem(.gradebook)
                        }
                        
                        MenuItemView(
                            icon: "graduationcap.fill",
                            title: "Учеба",
                            color: .indigo,
                            isSelected: selectedMenuItem == .study
                        ) {
                            selectMenuItem(.study)
                        }
                        
                        MenuItemView(
                            icon: "person.3.fill",
                            title: "Группа",
                            color: .cyan,
                            isSelected: selectedMenuItem == .group
                        ) {
                            selectMenuItem(.group)
                        }
                        
                        MenuItemView(
                            icon: "books.vertical.fill",
                            title: "Библиотека",
                            color: .brown,
                            isSelected: selectedMenuItem == .library
                        ) {
                            selectMenuItem(.library)
                        }
                        
                        MenuItemView(
                            icon: "megaphone.fill",
                            title: "Объявления",
                            color: .red,
                            isSelected: selectedMenuItem == .announcements
                        ) {
                            selectMenuItem(.announcements)
                        }
                        
                        MenuItemView(
                            icon: "doc.text.fill",
                            title: "Диплом",
                            color: .teal,
                            isSelected: selectedMenuItem == .diploma
                        ) {
                            selectMenuItem(.diploma)
                        }
                        
                        MenuItemView(
                            icon: "building.2.fill",
                            title: "Общежитие",
                            color: .mint,
                            isSelected: selectedMenuItem == .dormitory
                        ) {
                            selectMenuItem(.dormitory)
                        }
                        
                        MenuItemView(
                            icon: "exclamationmark.triangle.fill",
                            title: "Взыскания",
                            color: .yellow,
                            isSelected: selectedMenuItem == .penalties
                        ) {
                            selectMenuItem(.penalties)
                        }
                        
                        MenuItemView(
                            icon: "sparkles",
                            title: "Активности",
                            color: .pink,
                            isSelected: selectedMenuItem == .activities
                        ) {
                            selectMenuItem(.activities)
                        }
                        
                        MenuItemView(
                            icon: "gearshape.fill",
                            title: "Настройки",
                            color: .gray,
                            isSelected: selectedMenuItem == .settings
                        ) {
                            selectMenuItem(.settings)
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.3),
                                                .white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    }
                    .frame(width: 200)
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
        }
    }
    
    private func selectMenuItem(_ item: MenuItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            selectedMenuItem = item
            isMenuOpen = false
        }
    }
}

struct MenuItemView: View {
    let icon: String
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? color : .primary)
                    .frame(width: 24)
                
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? color : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color(uiColor: .systemBackground)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            HStack {
                Spacer()
                MenuButton(
                    isMenuOpen: .constant(true),
                    selectedMenuItem: .constant(.gradebook)
                )
                .padding()
            }
        }
    }
}
