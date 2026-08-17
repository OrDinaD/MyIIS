//
//  ScheduleColorPreferences.swift
//  MyIIS
//
import Foundation
import SwiftUI

public enum LessonTypeCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case lecture
    case practice
    case laboratory
    case consultation
    case exam
    case other

    public var id: String { rawValue }

    public var localizedTitle: String {
        switch self {
        case .lecture:
            return NSLocalizedString("lesson_type_lecture", value: "Лекция", comment: "")
        case .practice:
            return NSLocalizedString("lesson_type_practice", value: "Практическое занятие", comment: "")
        case .laboratory:
            return NSLocalizedString("lesson_type_laboratory", value: "Лабораторная работа", comment: "")
        case .consultation:
            return NSLocalizedString("lesson_type_consultation", value: "Консультация", comment: "")
        case .exam:
            return NSLocalizedString("lesson_type_exam", value: "Экзамен / Зачёт", comment: "")
        case .other:
            return NSLocalizedString("lesson_type_other", value: "Прочее / Мероприятие", comment: "")
        }
    }

    public var defaultHex: String {
        switch self {
        case .lecture:
            return "#34C759" // Green
        case .practice:
            return "#FF3B30" // Red
        case .laboratory:
            return "#FFCC00" // Yellow
        case .consultation:
            return "#AF52DE" // Purple
        case .exam:
            return "#FF2D55" // Pink/Exam Red
        case .other:
            return "#5AC8FA" // Teal
        }
    }

    public var defaultSymbolName: String {
        switch self {
        case .lecture:
            return "book.pages.fill"
        case .practice:
            return "pencil.and.ruler.fill"
        case .laboratory:
            return "flask.fill"
        case .consultation:
            return "person.2.wave.2.fill"
        case .exam:
            return "graduationcap.fill"
        case .other:
            return "calendar"
        }
    }

    public static func from(lessonTypeAbbrev: String?) -> LessonTypeCategory {
        guard let raw = lessonTypeAbbrev?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty else {
            return .other
        }

        if raw.contains("экзам") || raw.contains("зачет") || raw.contains("зачёт") || raw.contains("диф") || raw.contains("exam") {
            return .exam
        }
        if raw.contains("конс") || raw.contains("consult") {
            return .consultation
        }
        if raw.contains("лр") || raw.contains("лаб") || raw.contains("lab") {
            return .laboratory
        }
        if raw.contains("пз") || raw.contains("практ") || raw.contains("семин") || raw.contains("pract") {
            return .practice
        }
        if raw.contains("лк") || raw.contains("лек") || raw.contains("lect") {
            return .lecture
        }

        return .other
    }
}

public enum ScheduleColorPreferences {
    private static let keyPrefix = "schedule.color.category."

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    public static func hexColor(for category: LessonTypeCategory) -> String {
        defaults.string(forKey: keyPrefix + category.rawValue) ?? category.defaultHex
    }

    public static func color(for category: LessonTypeCategory) -> Color {
        let hex = hexColor(for: category)
        return Color(hex: hex) ?? Color(hex: category.defaultHex) ?? .blue
    }

    public static func color(for lessonTypeAbbrev: String?) -> Color {
        let category = LessonTypeCategory.from(lessonTypeAbbrev: lessonTypeAbbrev)
        return color(for: category)
    }

    public static func hexColor(for lessonTypeAbbrev: String?) -> String {
        let category = LessonTypeCategory.from(lessonTypeAbbrev: lessonTypeAbbrev)
        return hexColor(for: category)
    }

    public static func setHexColor(_ hex: String, for category: LessonTypeCategory) {
        defaults.set(hex, forKey: keyPrefix + category.rawValue)
        ScheduleDisplayPreferences.reloadClassScheduleWidget()
    }

    public static func resetColor(for category: LessonTypeCategory) {
        defaults.removeObject(forKey: keyPrefix + category.rawValue)
        ScheduleDisplayPreferences.reloadClassScheduleWidget()
    }

    public static func resetAllColors() {
        for category in LessonTypeCategory.allCases {
            defaults.removeObject(forKey: keyPrefix + category.rawValue)
        }
        ScheduleDisplayPreferences.reloadClassScheduleWidget()
    }

    public static func isCustomized(category: LessonTypeCategory) -> Bool {
        defaults.object(forKey: keyPrefix + category.rawValue) != nil
    }
}

public extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red, green, blue, alpha: Double
        if hexSanitized.count == 6 {
            red = Double((rgb >> 16) & 0xFF) / 255.0
            green = Double((rgb >> 8) & 0xFF) / 255.0
            blue = Double(rgb & 0xFF) / 255.0
            alpha = 1.0
        } else if hexSanitized.count == 8 {
            red = Double((rgb >> 24) & 0xFF) / 255.0
            green = Double((rgb >> 16) & 0xFF) / 255.0
            blue = Double((rgb >> 8) & 0xFF) / 255.0
            alpha = Double(rgb & 0xFF) / 255.0
        } else {
            return nil
        }

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        let redValue = Float(components[0])
        let greenValue = Float(components[1])
        let blueValue = Float(components[2])
        return String(
            format: "#%02lX%02lX%02lX",
            lroundf(redValue * 255),
            lroundf(greenValue * 255),
            lroundf(blueValue * 255)
        )
    }
}
