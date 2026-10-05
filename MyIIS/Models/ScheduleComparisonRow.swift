import Foundation

/// Shared row for intersecting lesson intervals in either group.
struct ScheduleComparisonRow: Identifiable, Sendable {
    let start: Int
    var end: Int
    var lessons: [[DisciplineSchedule]]
    var sharedLessons: [DisciplineSchedule] = []
    var id: Int { start }

    var startTime: String { String(format: "%02d:%02d", start / 60, start % 60) }
    var endTime: String { String(format: "%02d:%02d", end / 60, end % 60) }
    var capacity: Int { max(1, max(lessons[0].count, lessons[1].count)) }
}
