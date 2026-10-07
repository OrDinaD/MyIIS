//
//  FreeAuditoriesModels.swift
//  MyIIS
//

import Foundation

/// Информация о свободных и занятых аудиториях в корпусе.
public struct FreeAuditoriesResponse: Codable, Sendable {
    public let building: String
    public let day: String
    public let timeSlot: String
    public let weekNumber: Int
    public let totalAuditories: Int
    public let freeAuditories: [String]
    public let busyAuditories: [String]?

    public init(
        building: String,
        day: String,
        timeSlot: String,
        weekNumber: Int,
        totalAuditories: Int,
        freeAuditories: [String],
        busyAuditories: [String]? = nil
    ) {
        self.building = building
        self.day = day
        self.timeSlot = timeSlot
        self.weekNumber = weekNumber
        self.totalAuditories = totalAuditories
        self.freeAuditories = freeAuditories
        self.busyAuditories = busyAuditories
    }
}

/// Учебный слот времени (номер пары).
public struct LessonTimeSlot: Identifiable, Hashable, Sendable {
    public let slot: Int
    public let title: String
    public let timeIntervalString: String

    public var id: Int { slot }

    public static let allSlots: [LessonTimeSlot] = [
        LessonTimeSlot(slot: 1, title: "1 пара", timeIntervalString: "08:00–09:35"),
        LessonTimeSlot(slot: 2, title: "2 пара", timeIntervalString: "09:45–11:20"),
        LessonTimeSlot(slot: 3, title: "3 пара", timeIntervalString: "11:40–13:15"),
        LessonTimeSlot(slot: 4, title: "4 пара", timeIntervalString: "13:25–15:00"),
        LessonTimeSlot(slot: 5, title: "5 пара", timeIntervalString: "15:20–16:55"),
        LessonTimeSlot(slot: 6, title: "6 пара", timeIntervalString: "17:05–18:40"),
        LessonTimeSlot(slot: 7, title: "7 пара", timeIntervalString: "18:45–20:20")
    ]

    /// Определяет номер текущей пары по системному времени.
    public static func currentSlot(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let minutes = hour * 60 + minute

        if minutes < 9 * 60 + 40 {
            return 1
        } else if minutes < 11 * 60 + 30 {
            return 2
        } else if minutes < 13 * 60 + 20 {
            return 3
        } else if minutes < 15 * 60 + 10 {
            return 4
        } else if minutes < 17 * 60 + 0 {
            return 5
        } else if minutes < 18 * 60 + 42 {
            return 6
        } else {
            return 7
        }
    }
}

/// Корпуса БГУИР.
public enum BSUIRBuilding: String, CaseIterable, Identifiable, Sendable {
    case b4 = "4"
    case b1 = "1"
    case b2 = "2"
    case b3 = "3"
    case b5 = "5"
    case b7 = "7"
    case b8 = "8"

    public var id: String { rawValue }

    public var displayName: String {
        "\(rawValue) корпус"
    }

    public var shortName: String {
        "\(rawValue) к."
    }
}
