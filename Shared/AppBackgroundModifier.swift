//
//  AppBackgroundModifier.swift
//  MyIIS
//
import SwiftUI

private struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
            )
    }
}

extension View {
    func appBackground() -> some View {
        modifier(AppBackgroundModifier())
    }
}
