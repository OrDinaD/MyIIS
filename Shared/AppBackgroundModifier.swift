//
//  AppBackgroundModifier.swift
//  MyIIS
//
//  Created by OpenAI Assistant on 11.03.2026.
//

import SwiftUI

private struct AppBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
    }

    private var backgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.black.opacity(0.95),
                Color.accentPurple.opacity(0.35),
                Color(uiColor: .secondarySystemBackground).opacity(0.85)
            ]
        } else {
            return [
                Color(uiColor: .systemBackground),
                Color.accentPurple.opacity(0.18),
                Color(uiColor: .secondarySystemBackground)
            ]
        }
    }

    private var glowColors: [Color] {
        [
            Color.accentPurple.opacity(colorScheme == .dark ? 0.4 : 0.25),
            Color.clear
        ]
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }
}
