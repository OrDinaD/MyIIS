import Foundation
import SwiftUI

enum DeadlineUrgencyStatus: Equatable, Sendable {
    case completed
    case critical
    case warning
    case normal
    case missing
    case none

    @MainActor
    var tintColor: Color {
        switch self {
        case .completed: return .green
        case .critical: return .red
        case .warning: return .orange
        case .normal: return .blue
        case .missing: return .secondary
        case .none: return .secondary
        }
    }

    var iconName: String {
        switch self {
        case .completed: return "checkmark.circle.fill"
        case .critical: return "exclamationmark.circle.fill"
        case .warning: return "clock.badge.exclamationmark.fill"
        case .normal: return "calendar"
        case .missing, .none: return "calendar.badge.clock"
        }
    }
}

struct OverdueDeadlineItem: Identifiable, Equatable, Hashable, Codable, Sendable {
    let date: String
    let taskNumber: Int?

    var id: String { "\(date)|\(taskNumber ?? 0)" }

    var displayTitle: String {
        let shortDate = date.count >= 5 ? String(date.prefix(5)) : date
        if let taskNumber {
            return "\(shortDate) (№ \(taskNumber))"
        }
        return shortDate
    }
}

struct DisciplineDeadlineItem: Identifiable, Equatable, Hashable, Codable, Sendable {
    let id: String
    let discipline: String
    let fullDisciplineName: String?
    let submitted: Int
    let total: Int?
    let nearestDeadline: String?
    let nearestDeadlineTaskNumber: Int?
    let nearestDeadlineOverdue: Bool
    let overdueDeadlines: [OverdueDeadlineItem]
    let deadlinesMissing: Bool

    var percent: Int {
        guard let total, total > 0 else { return 0 }
        return Int(round(Double(submitted) / Double(total) * 100.0))
    }

    var isCompleted: Bool {
        guard let total else { return false }
        return submitted >= total && total > 0
    }

    var allSubmitted: Bool {
        isCompleted
    }

    var urgencyStatus: DeadlineUrgencyStatus {
        if isCompleted {
            return .completed
        }
        if nearestDeadlineOverdue {
            return .critical
        }
        if deadlinesMissing {
            return .missing
        }
        guard let deadline = nearestDeadline else {
            return .none
        }

        let parts = deadline.split(separator: ".")
        guard parts.count == 3,
              let day = Int(parts[0]),
              let month = Int(parts[1]),
              let year = Int(parts[2]) else {
            return .normal
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day

        guard let targetDate = calendar.date(from: comps) else {
            return .normal
        }

        let today = calendar.startOfDay(for: Date())
        let daysLeft = calendar.dateComponents([.day], from: today, to: targetDate).day ?? 0

        if daysLeft <= 3 {
            return .critical
        } else if daysLeft <= 7 {
            return .warning
        } else {
            return .normal
        }
    }

    var nearestDeadlineFormatted: String? {
        guard let deadline = nearestDeadline else { return nil }
        let shortDate = deadline.count >= 5 ? String(deadline.prefix(5)) : deadline
        if let taskNumber = nearestDeadlineTaskNumber {
            return "\(shortDate) (№ \(taskNumber))"
        }
        return shortDate
    }
}

struct CheckpointSummaryItem: Identifiable, Equatable, Hashable, Codable, Sendable {
    let id: String
    let number: Int?
    let date: String
    let averageGrade: Double?
    let delta: Double?
    let absences: Int
    let submittedLabs: Int
    let expectedLabs: Int?
    let isTotal: Bool
    let isAfterCp: Bool
}
