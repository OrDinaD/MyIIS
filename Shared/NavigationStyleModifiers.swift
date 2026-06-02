//
//  NavigationStyleModifiers.swift
//  MyIIS
//
import SwiftUI

/// Adds a glass-like background to the navigation bar and a subtle top fade
/// to soften the transition when content scrolls underneath.
private struct GlassNavigationBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .overlay(alignment: .top) {
                NavigationTopFade()
                    .allowsHitTesting(false)
            }
    }
}

/// Provides consistent padding at the top of scrollable content so that headers
/// do not appear clipped when interacting with large navigation titles.
private struct GlassScrollPaddingModifier: ViewModifier {
    let top: CGFloat

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 17.0, *) {
                content
                    .contentMargins(.top, top, for: .scrollContent)
                    .contentMargins(.top, top, for: .scrollIndicators)
                    .safeAreaPadding(.top, top)
            } else {
                content
                    .padding(.top, top)
            }
        }
    }
}

private struct NavigationTopFade: View {
    @Environment(\.colorScheme) private var colorScheme

    private var colors: [Color] {
        if colorScheme == .dark {
            return [
                Color.black.opacity(0.35),
                Color.black.opacity(0.0)
            ]
        } else {
            return [
                Color.white.opacity(0.65),
                Color.white.opacity(0.0)
            ]
        }
    }

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 48)
        .ignoresSafeArea(edges: .top)
    }
}

extension View {
    func glassNavigationBar() -> some View {
        modifier(GlassNavigationBarModifier())
    }

    func glassScrollPadding(top: CGFloat = 28) -> some View {
        modifier(GlassScrollPaddingModifier(top: top))
    }

    @ViewBuilder
    func hiddenNavigationBarBackground() -> some View {
        if #available(iOS 18.0, *) {
            toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        } else {
            toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}
