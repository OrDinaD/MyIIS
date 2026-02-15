//
//  CustomTabBar.swift
//  MyIIS
//
//  Created by GitHub Copilot on 15.10.25.
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    @State private var showMenu = false
    
    private let mainTabs: [Tab] = [.profile, .attendance, .rating]
    
    var body: some View {
        HStack(spacing: 12) {
            // Основной блок с 3 кнопками
            HStack(spacing: 0) {
                ForEach(mainTabs) { tab in
                    TabBarButton(tab: tab, isSelected: selectedTab == tab) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(LinearGradient.glassBorder, lineWidth: 1)
            }
            
            // Отдельная кнопка "Еще" справа (как поиск в видео)
            Menu {
                ForEach(Tab.allCases.filter { !mainTabs.contains($0) }) { tab in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    } label: {
                        Label(tab.title, systemImage: tab.icon)
                    }
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentPurple, Color.accentPurple.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .shadow(color: Color.accentPurple.opacity(0.3), radius: 10, x: 0, y: 5)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .liquidGlassShadow(radius: 10)
    }
}

private struct TabBarButton: View {
    let tab: Tab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? tab.icon : tab.icon.replacingOccurrences(of: ".fill", with: ""))
                    .font(.system(size: 20, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.accentPurple : Color.primary.opacity(0.6))
                
                if isSelected {
                    Circle()
                        .fill(Color.accentPurple)
                        .frame(width: 4, height: 4)
                        .transition(.scale)
                }
            }
            .frame(width: 70, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        VStack {
            Spacer()
            CustomTabBar(selectedTab: .constant(.profile))
        }
    }
}
