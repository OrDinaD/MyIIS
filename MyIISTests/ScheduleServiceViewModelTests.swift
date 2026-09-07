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

    func testDateJumpBuildsTimelineAroundSelectedDate() async throws {
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

        let dayID = await viewModel.prepareContinuousTimeline(around: requestedDate)

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

    func testGroupSearchTrimsQueryAndMatchesSpeciality() async throws {
        let defaults = makeDefaults("group-search")
        defer { removeDefaults("group-search") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.groups = [
            makeGroup(name: "420603", speciality: "Информационные системы"),
            makeGroup(name: "310901", speciality: "Программная инженерия")
        ]

        viewModel.query = "  4206  "
        try await Task.sleep(for: .milliseconds(180))
        XCTAssertEqual(viewModel.filteredGroups.map(\.name), ["420603"])

        viewModel.query = "ИНЖЕНЕРИЯ"
        try await Task.sleep(for: .milliseconds(180))
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

    func testInitializationIsLightweightAndDoesNotPerformSynchronousSnapshotRestore() {
        let defaults = makeDefaults("lightweight_init")
        defer { removeDefaults("lightweight_init") }

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<50 {
            let instance = ScheduleServiceViewModel(defaults: defaults)
            XCTAssertNil(instance.schedule)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        XCTAssertLessThan(elapsed, 0.2, "Initializing ScheduleServiceViewModel must be lightweight (< 200ms for 50 instances)")
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

    func testSubgroupPreferencePreservedAcrossTeacherNavigation() {
        let defaults = makeDefaults("subgroup-preserve")
        defer { removeDefaults("subgroup-preserve") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        let groupLesson1 = makeLesson(id: "g1", subgroup: 1)
        let groupLesson2 = makeLesson(id: "g2", subgroup: 2)
        let groupSchedule = makePublicSchedule(lessons: [groupLesson1, groupLesson2])

        viewModel.applyGroupSchedule(groupSchedule, week: 1, groupNumber: "420602")
        viewModel.subgroupFilter = .subgroup(2)
        XCTAssertEqual(defaults.integer(forKey: "services.schedule.subgroupFilter"), 2)

        // Switch to teacher schedule
        let teacherSchedule = makePublicSchedule(lessons: [makeLesson(id: "t1")])
        viewModel.schedule = teacherSchedule
        viewModel.mode = .teacher
        viewModel.subgroupFilter = .all

        XCTAssertEqual(viewModel.mode, .teacher)
        XCTAssertEqual(viewModel.subgroupFilter, .all)
        // Subgroup filter setting for student groups must remain untouched in UserDefaults
        XCTAssertEqual(defaults.integer(forKey: "services.schedule.subgroupFilter"), 2)

        // Switch back to group schedule
        viewModel.applyGroupSchedule(groupSchedule, week: 1, groupNumber: "420602")
        XCTAssertEqual(viewModel.mode, .group)
        XCTAssertEqual(viewModel.subgroupFilter, .subgroup(2))
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

    func testScheduleEnumsAndFilterProperties() {
        for mode in ScheduleLookupMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
            XCTAssertFalse(mode.title.isEmpty)
        }

        for display in ScheduleDisplayMode.allCases {
            XCTAssertEqual(display.id, display.rawValue)
            XCTAssertFalse(display.title.isEmpty)
        }

        for source in ScheduleDataSource.allCases {
            XCTAssertEqual(source.id, source.rawValue)
            XCTAssertFalse(source.title.isEmpty)
        }

        let allSubgroup = ScheduleSubgroupFilter.all
        XCTAssertEqual(allSubgroup.id, "all")
        XCTAssertFalse(allSubgroup.localizedTitle.isEmpty)
        XCTAssertFalse(allSubgroup.shortTitle.isEmpty)

        let specificSubgroup = ScheduleSubgroupFilter.subgroup(2)
        XCTAssertEqual(specificSubgroup.id, "subgroup_2")
        XCTAssertFalse(specificSubgroup.localizedTitle.isEmpty)
        XCTAssertEqual(specificSubgroup.shortTitle, "2")
    }

    func testPinnedGroupsToggleAndPersistence() {
        let defaults = makeDefaults("pinned-groups")
        defer { removeDefaults("pinned-groups") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)

        XCTAssertFalse(viewModel.isGroupPinned("420603"))

        viewModel.togglePinnedGroupName("420603")
        XCTAssertTrue(viewModel.isGroupPinned("420603"))
        XCTAssertTrue(viewModel.pinnedGroupNames.contains("420603"))

        // Toggle again unpins
        viewModel.togglePinnedGroupName("420603")
        XCTAssertFalse(viewModel.isGroupPinned("420603"))
        XCTAssertFalse(viewModel.pinnedGroupNames.contains("420603"))
    }

    func testPinnedTeachersToggleAndPersistence() {
        let defaults = makeDefaults("pinned-teachers")
        defer { removeDefaults("pinned-teachers") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        let teacher = PinnedTeacher(urlId: "i-abramov", name: "Абрамов И.И.", photoLink: nil)

        XCTAssertEqual(teacher.id, "i-abramov")
        XCTAssertFalse(viewModel.isTeacherPinned("i-abramov"))

        viewModel.togglePinnedTeacher(teacher)
        XCTAssertTrue(viewModel.isTeacherPinned("i-abramov"))
        XCTAssertTrue(viewModel.pinnedTeachers.contains(where: { $0.urlId == "i-abramov" }))

        // Toggle unpins
        viewModel.togglePinnedTeacher(teacher)
        XCTAssertFalse(viewModel.isTeacherPinned("i-abramov"))
        XCTAssertFalse(viewModel.pinnedTeachers.contains(where: { $0.urlId == "i-abramov" }))
    }

    func testRecentGroupsAndTeachersTracking() {
        let defaults = makeDefaults("recent-items")
        defer { removeDefaults("recent-items") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)

        viewModel.recordRecentGroup("420603")
        XCTAssertTrue(viewModel.recentGroupNames.contains("420603"))

        let entry = ScheduleEmployeeDirectoryEntry(
            firstName: "Иван",
            lastName: "Иванов",
            middleName: "Иванович",
            degree: nil,
            rank: nil,
            photoLink: nil,
            calendarId: nil,
            id: 101,
            urlId: "test-teacher",
            fio: "Иванов Иван Иванович"
        )
        viewModel.recordRecentTeacher(entry)
        XCTAssertTrue(viewModel.recentTeachers.contains(where: { $0.urlId == "test-teacher" }))
    }

    func testFilteredEmployeesSearchAndTransliteration() async throws {
        let defaults = makeDefaults("employees-search")
        defer { removeDefaults("employees-search") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.employees = [
            ScheduleEmployeeDirectoryEntry(
                firstName: "Игорь",
                lastName: "Абрамов",
                middleName: "Иванович",
                degree: "д.т.н.",
                rank: "профессор",
                photoLink: nil,
                calendarId: nil,
                id: 500434,
                urlId: "i-abramov",
                fio: "Абрамов Игорь Иванович"
            ),
            ScheduleEmployeeDirectoryEntry(
                firstName: "Елена",
                lastName: "Сидорова",
                middleName: "Петровна",
                degree: "к.т.н.",
                rank: "доцент",
                photoLink: nil,
                calendarId: nil,
                id: 500123,
                urlId: "e-sidorova",
                fio: "Сидорова Елена Петровна"
            )
        ]

        viewModel.mode = .teacher
        viewModel.query = "абрамов"
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(viewModel.filteredEmployees.map(\.urlId), ["i-abramov"])

        viewModel.query = "елена"
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(viewModel.filteredEmployees.map(\.urlId), ["e-sidorova"])
    }

    func testContinuousDayAndExamDayIdentifiers() {
        let date = Date(timeIntervalSince1970: 1780000000)
        let continuousDay = ScheduleContinuousDay(
            date: date,
            weekday: .monday,
            weekNumber: 1,
            lessons: []
        )
        XCTAssertFalse(continuousDay.id.isEmpty)

        let examDay = ExamScheduleDay(
            date: date,
            weekday: .monday,
            lessons: []
        )
        XCTAssertFalse(examDay.id.isEmpty)
    }

    func testScheduleServicePerformanceBenchmark() {
        let defaults = makeDefaults("bench")
        defer { removeDefaults("bench") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)

        var lessons: [DisciplineSchedule] = []
        for i in 0..<100 {
            lessons.append(makeLesson(id: "lesson-\(i)", weeks: [1, 2, 3, 4], subgroup: i % 3))
        }
        viewModel.schedule = makePublicSchedule(lessons: lessons)

        measure {
            for mode in [ScheduleDisplayMode.continuous, .byDay, .exams] {
                viewModel.displayMode = mode
                _ = viewModel.filteredDays
                _ = viewModel.weekFilters
                _ = viewModel.subgroupFilters
            }
        }
    }

    func testRotatingWeekNumberUsesPublishedTermStartDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let termStart = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))
        )
        let sameWeek = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 6))
        )
        let nextWeek = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 7))
        )
        let fourthWeek = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 21))
        )
        let fifthWeek = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 28))
        )

        XCTAssertEqual(
            ScheduleServiceViewModel.rotatingWeekNumber(
                on: sameWeek,
                termStartDate: termStart,
                calendar: calendar
            ),
            1
        )
        XCTAssertEqual(
            ScheduleServiceViewModel.rotatingWeekNumber(
                on: nextWeek,
                termStartDate: termStart,
                calendar: calendar
            ),
            2
        )
        XCTAssertEqual(
            ScheduleServiceViewModel.rotatingWeekNumber(
                on: fourthWeek,
                termStartDate: termStart,
                calendar: calendar
            ),
            4
        )
        XCTAssertEqual(
            ScheduleServiceViewModel.rotatingWeekNumber(
                on: fifthWeek,
                termStartDate: termStart,
                calendar: calendar
            ),
            1
        )
    }

    func testRotatingWeekNumberRejectsDatesBeforeTerm() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let termStart = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))
        )
        let previousWeek = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 24))
        )

        XCTAssertNil(
            ScheduleServiceViewModel.rotatingWeekNumber(
                on: previousWeek,
                termStartDate: termStart,
                calendar: calendar
            )
        )
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
