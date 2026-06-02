//
//  Color+Extensions.swift
//  MyIIS
//
//  Адаптивные цвета для Dark Mode поддержки
//

import SwiftUI

extension Color {
    // MARK: - Adaptive Liquid Glass Colors

    /// Адаптивный цвет для верхнего блика на glass компонентах
    /// Light: белый с opacity, Dark: светло-серый с меньшей opacity
    static var glassHighlight: Color {
        Color(uiColor: .systemBackground).opacity(0.6)
    }

    /// Адаптивный цвет для среднего слоя glass эффекта
    static var glassMid: Color {
        Color(uiColor: .systemBackground).opacity(0.3)
    }

    /// Адаптивный цвет для границ glass компонентов
    static var glassBorder: Color {
        Color(uiColor: .separator)
    }

    /// Адаптивный легкий блик для overlay
    static var glassOverlay: Color {
        Color(uiColor: .systemBackground).opacity(0.15)
    }

    // MARK: - Adaptive Shadow Colors

    /// Адаптивная тень - более прозрачная в темной теме
    static func adaptiveShadow(opacity: Double = 0.1) -> Color {
        Color.primary.opacity(opacity * 0.5)
    }

    // MARK: - Adaptive Accent Colors

    /// Основной акцентный фиолетовый с адаптацией яркости
    static var accentPurple: Color {
        Color(light: Color(red: 0.5, green: 0.0, blue: 0.8),
              dark: Color(red: 0.7, green: 0.3, blue: 0.9))
    }

    /// Более мягкий фиолетовый для вторичных элементов
    static var accentPurpleSoft: Color {
        Color(light: Color.purple.opacity(0.7),
              dark: Color.purple.opacity(0.6))
    }

    // MARK: - Helper for Light/Dark Colors

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }

    // MARK: - Adaptive Backgrounds

    /// Адаптивный фон для градиентов
    static var gradientBackground: [Color] {
        [
            Color(uiColor: .systemGroupedBackground),
            Color(uiColor: .secondarySystemGroupedBackground)
        ]
    }

    /// Адаптивный градиент для кнопок
    static var buttonGradient: [Color] {
        [
            Color.accentPurple,
            Color.accentPurple.opacity(0.8)
        ]
    }

    /// Адаптивный градиент для иконок
    static func iconGradient(baseColor: Color) -> [Color] {
        [
            baseColor,
            baseColor.opacity(0.7)
        ]
    }

    // MARK: - Semantic Status Colors (адаптивные версии)

    /// Адаптивный зеленый для успеха
    static var statusSuccess: Color {
        Color(light: .green, dark: Color(red: 0.2, green: 0.8, blue: 0.4))
    }

    /// Адаптивный оранжевый для предупреждений
    static var statusWarning: Color {
        Color(light: .orange, dark: Color(red: 1.0, green: 0.7, blue: 0.2))
    }

    /// Адаптивный красный для ошибок
    static var statusError: Color {
        Color(light: .red, dark: Color(red: 1.0, green: 0.3, blue: 0.3))
    }

    /// Адаптивный желтый для рейтинга
    static var ratingYellow: Color {
        Color(light: .yellow, dark: Color(red: 1.0, green: 0.8, blue: 0.0))
    }
}

// MARK: - Shadow Modifier Extension

extension View {
    /// Применяет адаптивную тень для Liquid Glass эффекта
    func liquidGlassShadow(color: Color = .accentPurple, radius: CGFloat = 20) -> some View {
        self
            .shadow(color: color.opacity(0.15), radius: radius * 0.6, x: 0, y: radius * 0.5)
            .shadow(color: color.opacity(0.08), radius: radius * 0.75, x: 0, y: radius * 0.75)
    }

    /// Применяет адаптивную тень для карточек
    func cardShadow() -> some View {
        self
            .shadow(color: Color.adaptiveShadow(opacity: 0.08), radius: 12, x: 0, y: 6)
            .shadow(color: Color.accentPurple.opacity(0.05), radius: 20, x: 0, y: 10)
    }
}

// MARK: - Gradient Helpers

extension LinearGradient {
    /// Адаптивный градиент для glass границ
    static var glassBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color.glassHighlight,
                Color.glassMid,
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Адаптивный градиент для glass overlay
    static var glassOverlay: LinearGradient {
        LinearGradient(
            colors: [
                Color.glassOverlay,
                Color.clear
            ],
            startPoint: .top,
            endPoint: .center
        )
    }

    /// Адаптивный градиент для иконок с цветом
    static func iconGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: Color.iconGradient(baseColor: color),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
