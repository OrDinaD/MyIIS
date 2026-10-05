@testable import MyIIS
import XCTest

@MainActor
final class ScheduleTimelineRegressionTests: XCTestCase {
    func testDateJumpRepairsDuplicateDaysWithoutCrashing() async throws {
        let suite = "ScheduleTimelineRegression.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = ScheduleServiceViewModel(defaults: defaults)
        model.schedule = try JSONDecoder().decode(
            PublicScheduleResponse.self, from: Data(#"{"schedules":{}}"#.utf8)
        )
        let date = Calendar.current.startOfDay(for: Date())
        let day = ScheduleContinuousDay(date: date, weekday: .monday, weekNumber: 1, lessons: [])
        model.continuousTimelineDays = [day, day]
        model.continuousCursorDate = date

        _ = await model.prepareContinuousTimeline(around: date)

        XCTAssertEqual(model.continuousTimelineDays.count, 1)
        XCTAssertEqual(model.continuousTimelineDays.first?.id, day.id)
        XCTAssertGreaterThan(try XCTUnwrap(model.continuousCursorDate), date)
    }
}
