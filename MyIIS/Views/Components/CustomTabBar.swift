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
    private let otherTabs: [Tab] = [.others] // Здесь можно добавить больше, если появятся новые
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(mainTabs) { tab in
                TabBarButton(tab: tab, isSelected: selectedTab == tab) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                }
            }
            
            // Кнопка-кружок для меню
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
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accentPurple, Color.accentPurple.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.bounce, value: showMenu)
                    
                    Text("Еще")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .onTapGesture {
                showMenu.toggle()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(LinearGradient.glassOverlay)
                }
                .overlay {
                    Capsule()
                        .stroke(LinearGradient.glassBorder, lineWidth: 1.5)
                }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8) // Небольшой отступ от низа
        .liquidGlassShadow(radius: 15)
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
                    .font(.system(size: 22, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.accentPurple : Color.secondary)
                    .scaleEffect(isSelected ? 1.15 : 1.0)
                    .glow(color: Color.accentPurple, radius: isSelected ? 8 : 0)
                
                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color.accentPurple : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Вспомогательный эффект свечения
extension View {
    func glow(color: Color, radius: CGFloat) -> some View {
        self.shadow(color: color.opacity(radius > 0 ? 0.5 : 0), radius: radius)
            .shadow(color: color.opacity(radius > 0 ? 0.2 : 0), radius: radius / 2)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            Spacer()
            CustomTabBar(selectedTab: .constant(.profile))
        }
    }
}
