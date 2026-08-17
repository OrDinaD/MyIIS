@testable import MyIIS
import XCTest

@MainActor
// The helpers below intentionally form one fixture family for schedule behavior.
// swiftlint:disable:next type_body_length
final class ScheduleServiceViewModelTests: XCTestCase {
    func testAPISourceDoesNotRestoreLocalSnapshot() {
        let localDefaults = makeDefaults("local-snapshot")
        defer { removeDefaults("local-snapshot") }
        localDefaults.set(
            ScheduleDataSource.localJSON.rawValue,
            forKey: "services.schedule.dataSource"
        )
        let localViewModel = ScheduleServiceViewModel(defaults: localDefaults)
        localViewModel.applyLocalSchedule(
            makeDocument(events: [makeEvent(id: "local")])
        )

        let apiDefaults = makeDefaults("api-after-local")
        defer { removeDefaults("api-after-local") }
        apiDefaults.set(
            ScheduleDataSource.api.rawValue,
            forKey: "services.schedule.dataSource"
        )

        let apiViewModel = ScheduleServiceViewModel(defaults: apiDefaults)

        XCTAssertEqual(apiViewModel.dataSource, .api)
        XCTAssertNil(apiViewModel.localScheduleDocument)
        XCTAssertNotEqual(
            apiViewModel.schedule?.orderedDays.flatMap(\.lessons).map(\.id),
            ["local"]
        )
    }

    func testPublicationPendingStateUsesStableHeaderAndHidesFilters() {
        let defaults = makeDefaults("publication-pending")
        defer { removeDefaults("publication-pending") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.schedule = .publicationPending
        viewModel.displayMode = .byDay

        XCTAssertTrue(viewModel.isSchedulePublicationPending)
        XCTAssertTrue(viewModel.isCurrentModeEmpty)
        XCTAssertTrue(viewModel.weekFilters.isEmpty)
        XCTAssertFalse(viewModel.shouldShowWeekFilter)
        XCTAssertEqual(
            viewModel.scheduleHeaderTitle,
            NSLocalizedString("services_schedule_title", comment: "")
        )
        XCTAssertEqual(
            viewModel.currentModeEmptyText,
            NSLocalizedString("services_schedule_publication_pending", comment: "")
        )
    }

    func testWeekAndSubgroupFiltersKeepSharedLessons() {
        let defaults = makeDefaults("filters")
        defer { removeDefaults("filters") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        let shared = makeLesson(id: "shared", weeks: [], subgroup: 0)
        let first = makeLesson(id: "first", weeks: [1], subgroup: 1)
        let second = makeLesson(id: "second", weeks: [2], subgroup: 2)
        viewModel.schedule = makePublicSchedule(lessons: [shared, first, second])
        viewModel.displayMode = .byDay

        XCTAssertEqual(viewModel.weekFilters, [.all, .week(1), .week(2)])
        XCTAssertEqual(viewModel.subgroupFilters, [.all, .subgroup(1), .subgroup(2)])

        viewModel.weekFilter = .week(1)
        viewModel.subgroupFilter = .subgroup(1)

        XCTAssertEqual(
            viewModel.filteredDays.flatMap(\.lessons).map(\.id),
            ["shared", "first"]
        )

        viewModel.weekFilter = .all
        XCTAssertEqual(
            viewModel.filteredDays.flatMap(\.lessons).map(\.id),
            ["shared", "first", "second"]
        )
        XCTAssertTrue(viewModel.isOtherSubgroupLesson(second))

        defaults.set(
            ScheduleOtherSubgroupDisplay.hidden.rawValue,
            forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey
        )
        viewModel.refreshSubgroupPresentation()

        XCTAssertEqual(
            viewModel.filteredDays.flatMap(\.lessons).map(\.id),
            ["shared", "first"]
        )
    }

    func testDateJumpBuildsTimelineAroundSelectedDate() throws {
        let defaults = makeDefaults("date-jump")
        defer { removeDefaults("date-jump") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.schedule = makePublicSchedule(lessons: [makeLesson(id: "lesson")])

        let calendar = Calendar.current
        let requestedDate = try XCTUnwrap(
            calendar.nextDate(
                after: calendar.date(byAdding: .day, value: 40, to: Date()) ?? Date(),
                matching: DateComponents(weekday: 2),
                matchingPolicy: .nextTime
            )
        )

        let dayID = viewModel.prepareContinuousTimeline(around: requestedDate)

        XCTAssertNotNil(dayID)
        XCTAssertTrue(
            viewModel.continuousTimelineDays.contains {
                calendar.isDate($0.date, inSameDayAs: requestedDate)
            }
        )
    }

    func testApplyingLocalScheduleRemovesCancelledEventsAndSelectsStableMode() {
        let defaults = makeDefaults("apply-local")
        defer { removeDefaults("apply-local") }
        let visible = makeEvent(id: "visible")
        let cancelled = makeEvent(id: "cancelled", isCancelled: true)
        let document = makeDocument(events: [cancelled, visible])
        let viewModel = ScheduleServiceViewModel(defaults: defaults)

        viewModel.applyLocalSchedule(document)

        XCTAssertEqual(
            viewModel.schedule?.orderedDays.flatMap(\.lessons).map(\.id),
            ["visible"]
        )
        XCTAssertEqual(viewModel.displayMode, .continuous)
        XCTAssertEqual(viewModel.weekFilter, .all)
        XCTAssertEqual(viewModel.mode, .group)
        XCTAssertEqual(viewModel.query, document.title)
    }

    func testGroupSearchTrimsQueryAndMatchesSpeciality() {
        let defaults = makeDefaults("group-search")
        defer { removeDefaults("group-search") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.groups = [
            makeGroup(name: "420603", speciality: "Информационные системы"),
            makeGroup(name: "310901", speciality: "Программная инженерия")
        ]

        viewModel.query = "  4206  "
        XCTAssertEqual(viewModel.filteredGroups.map(\.name), ["420603"])

        viewModel.query = "ИНЖЕНЕРИЯ"
        XCTAssertEqual(viewModel.filteredGroups.map(\.name), ["310901"])
    }

    func testDisplayAndSubgroupSelectionsPersistAcrossViewModelRecreation() {
        let defaults = makeDefaults("persistence")
        defer { removeDefaults("persistence") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.displayMode = .exams
        viewModel.subgroupFilter = .subgroup(2)

        let restored = ScheduleServiceViewModel(defaults: defaults)

        XCTAssertEqual(restored.displayMode, .exams)
        XCTAssertEqual(restored.subgroupFilter, .subgroup(2))
    }

    func testAPIScheduleSeparatesRegularAndExamLikeEvents() {
        let document = makeDocument(events: [
            makeEvent(id: "lesson", type: .lecture),
            makeEvent(id: "exam", type: .exam),
            makeEvent(id: "consultation", type: .consultation),
            makeEvent(id: "announcement", type: .announcement)
        ])

        let schedule = document.apiSchedule()

        XCTAssertEqual(schedule.orderedDays.flatMap(\.lessons).map(\.id), ["lesson"])
        XCTAssertEqual(
            Set(schedule.exams.map(\.id)),
            Set(["exam", "consultation", "announcement"])
        )
    }

    func testTeacherScheduleContainsOnlyRequestedTeacher() {
        let firstTeacher = makeTeacher(id: 1, lastName: "Иванов")
        let secondTeacher = makeTeacher(id: 2, lastName: "Петров")
        let document = makeDocument(events: [
            makeEvent(id: "first", teacherDetails: firstTeacher),
            makeEvent(id: "second", teacherDetails: secondTeacher)
        ])

        let schedule = document.apiSchedule(teacherID: firstTeacher.id)

        XCTAssertNil(schedule.group)
        XCTAssertEqual(schedule.employee?.id, firstTeacher.id)
        XCTAssertEqual(schedule.orderedDays.flatMap(\.lessons).map(\.id), ["first"])
    }

    func testExactDateLessonDoesNotRepeatOnSameWeekday() {
        let exactDate = Date(timeIntervalSince1970: 1_775_344_400)
        let nextWeek = exactDate.addingTimeInterval(7 * 24 * 60 * 60)
        let exactLesson = makeLesson(id: "exact", lessonDate: exactDate)
        let recurringLesson = makeLesson(id: "recurring")

        XCTAssertTrue(
            ScheduleServiceViewModel.isLessonScheduledOnContinuousDay(exactLesson, date: exactDate)
        )
        XCTAssertFalse(
            ScheduleServiceViewModel.isLessonScheduledOnContinuousDay(exactLesson, date: nextWeek)
        )
        XCTAssertTrue(
            ScheduleServiceViewModel.isLessonScheduledOnContinuousDay(recurringLesson, date: exactDate)
        )
        XCTAssertTrue(
            ScheduleServiceViewModel.isLessonScheduledOnContinuousDay(recurringLesson, date: nextWeek)
        )
    }

    func testClearingLocalScheduleRemovesDisplayedState() {
        let defaults = makeDefaults("clear-local")
        defer { removeDefaults("clear-local") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.dataSource = .localJSON
        viewModel.applyLocalSchedule(makeDocument(events: [makeEvent(id: "visible")]))

        viewModel.clearLocalSchedule()

        XCTAssertNil(viewModel.schedule)
        XCTAssertNil(viewModel.selectedEmployee)
        XCTAssertNil(viewModel.currentWeekNumber)
        XCTAssertTrue(viewModel.continuousTimelineDays.isEmpty)
    }

    private func makeDefaults(_ identifier: String) -> UserDefaults {
        let suiteName = defaultsSuiteName(identifier)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func removeDefaults(_ identifier: String) {
        UserDefaults.standard.removePersistentDomain(
            forName: defaultsSuiteName(identifier)
        )
    }

    private func defaultsSuiteName(_ identifier: String) -> String {
        "ScheduleServiceViewModelTests.\(identifier)"
    }

    private func makeGroup(name: String, speciality: String) -> StudyGroup {
        StudyGroup(
            name: name,
            facultyId: nil,
            facultyAbbrev: nil,
            facultyName: nil,
            specialityDepartmentEducationFormId: nil,
            specialityName: speciality,
            specialityAbbrev: nil,
            course: nil,
            id: nil,
            calendarId: nil,
            educationDegree: nil
        )
    }

    private func makeLesson(
        id: String,
        weeks: [Int] = [],
        subgroup: Int = 0,
        lessonDate: Date? = nil
    ) -> DisciplineSchedule {
        DisciplineSchedule(
            id: id,
            auditories: [],
            endLessonTime: "10:35",
            lessonTypeAbbrev: "ЛК",
            note: nil,
            subgroup: subgroup,
            startLessonTime: "09:00",
            studentGroups: [],
            subject: id,
            subjectFullName: nil,
            weekNumbers: weeks,
            employees: [],
            lessonDate: lessonDate,
            startLessonDate: nil,
            endLessonDate: nil,
            isAnnouncement: false,
            isSplit: false
        )
    }

    private func makePublicSchedule(
        lessons: [DisciplineSchedule],
        exams: [DisciplineSchedule] = []
    ) -> PublicScheduleResponse {
        PublicScheduleResponse(
            employee: nil,
            group: nil,
            exams: exams,
            startDate: nil,
            endDate: nil,
            startExamsDate: nil,
            endExamsDate: nil,
            scheduleByWeekday: [.monday: lessons],
            previousScheduleByWeekday: [:],
            nextScheduleByWeekday: [:]
        )
    }

    private func makeTeacher(
        id: Int,
        lastName: String
    ) -> LocalScheduleDocument.Teacher {
        LocalScheduleDocument.Teacher(
            id: id,
            firstName: "Имя",
            middleName: nil,
            lastName: lastName,
            degree: nil,
            rank: nil,
            photoLink: nil,
            urlId: "teacher-\(id)",
            calendarId: nil
        )
    }

    private func makeDocument(
        events: [LocalScheduleDocument.Event]
    ) -> LocalScheduleDocument {
        LocalScheduleDocument(
            schemaVersion: LocalScheduleDocument.currentSchemaVersion,
            id: "schedule",
            title: "Расписание",
            groupName: nil,
            timeZone: "Europe/Minsk",
            validFrom: nil,
            validThrough: nil,
            updatedAt: nil,
            events: events
        )
    }

    private func makeEvent(
        id: String,
        type: LocalScheduleEventType = .lecture,
        teacherDetails: LocalScheduleDocument.Teacher? = nil,
        isCancelled: Bool = false
    ) -> LocalScheduleDocument.Event {
        LocalScheduleDocument.Event(
            id: id,
            date: "2026-08-03",
            startTime: "09:00",
            endTime: "10:30",
            title: id,
            type: type,
            location: "1-101",
            teacher: teacherDetails?.fullName,
            teacherDetails: teacherDetails,
            isCancelled: isCancelled
        )
    }
}
