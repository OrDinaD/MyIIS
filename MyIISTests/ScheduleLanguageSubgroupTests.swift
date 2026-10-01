@testable import MyIIS
import XCTest

@MainActor
final class ScheduleLanguageSubgroupTests: XCTestCase {
    func testLanguageSubgroupFiltersZeroSubgroupClassesIndependently() throws {
        let defaults = makeDefaults("language-independent")
        defer { removeDefaults("language-independent") }
        defaults.set("hidden", forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey)
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        let first = try makeLanguageLesson(teacherID: 501029, weeks: [1, 2, 3, 4])
        let second = try makeLanguageLesson(teacherID: 501048, weeks: [1, 2, 3, 4])
        let shared = makeLesson(id: "shared")
        let ordinary = makeLesson(id: "ordinary", subgroup: 2)
        viewModel.applyGroupSchedule(
            makePublicSchedule(lessons: [first, second, shared, ordinary]),
            week: 1, groupNumber: "620601"
        )
        viewModel.displayMode = .byDay
        viewModel.subgroupFilter = .subgroup(2)
        viewModel.languageSubgroupTeacherID = 501029

        XCTAssertEqual(viewModel.languageSubgroupOptions.map(\.id), [501029, 501048])
        XCTAssertTrue(viewModel.showsLanguageSubgroupPicker)
        XCTAssertEqual(Set(viewModel.filteredDays.flatMap(\.lessons).map(\.id)), Set([first.id, shared.id, ordinary.id]))
        XCTAssertTrue(viewModel.shouldKeepLessonForWidget(first))
        XCTAssertFalse(viewModel.shouldKeepLessonForWidget(second))
        viewModel.languageSubgroupTeacherID = nil
        XCTAssertTrue(viewModel.shouldKeepLessonForWidget(second))
    }

    func testLanguageChoicePersistsPerGroupAndAcrossReordering() throws {
        let defaults = makeDefaults("language-persistence")
        defer { removeDefaults("language-persistence") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        let first = try makeLanguageLesson(teacherID: 501029)
        let second = try makeLanguageLesson(teacherID: 501048)
        let schedule = makePublicSchedule(lessons: [first, second])
        viewModel.togglePinnedGroupName("620601")
        viewModel.togglePinnedGroupName("620603")
        viewModel.applyGroupSchedule(schedule, week: 1, groupNumber: "620601")
        viewModel.languageSubgroupTeacherID = 501029
        viewModel.applyGroupSchedule(schedule, week: 1, groupNumber: "620603")
        XCTAssertNil(viewModel.languageSubgroupTeacherID)
        viewModel.languageSubgroupTeacherID = 501048
        viewModel.applyGroupSchedule(
            makePublicSchedule(lessons: [second, first]), week: 1, groupNumber: "620601"
        )
        XCTAssertEqual(viewModel.languageSubgroupTeacherID, 501029)
        let restored = ScheduleServiceViewModel(defaults: defaults)
        restored.applyGroupSchedule(schedule, week: 1, groupNumber: "620603")
        XCTAssertEqual(restored.languageSubgroupTeacherID, 501048)
        restored.mode = .teacher
        XCTAssertTrue(restored.shouldKeepLanguageLesson(first))
        XCTAssertFalse(restored.showsLanguageSubgroupPicker)
    }

    func testLanguageChoicePreservedWhenScheduleTemporarilyHasNoSplit() throws {
        let defaults = makeDefaults("language-missing")
        defer { removeDefaults("language-missing") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        let first = try makeLanguageLesson(teacherID: 501029)
        let second = try makeLanguageLesson(teacherID: 501048)
        let schedule = makePublicSchedule(lessons: [first, second])
        viewModel.applyGroupSchedule(schedule, week: 1, groupNumber: "620601")
        viewModel.languageSubgroupTeacherID = 501029
        viewModel.applyGroupSchedule(makePublicSchedule(lessons: [second]), week: 1, groupNumber: "620601")
        XCTAssertNil(viewModel.languageSubgroupTeacherID)
        XCTAssertTrue(viewModel.shouldKeepLanguageLesson(second))
        viewModel.applyGroupSchedule(schedule, week: 1, groupNumber: "620601")
        XCTAssertEqual(viewModel.languageSubgroupTeacherID, 501029)
    }

    func testLanguageOptionsDoNotTreatAlternatingTeachersAsSubgroups() throws {
        let viewModel = ScheduleServiceViewModel(defaults: makeDefaults("language-alternating"))
        defer { removeDefaults("language-alternating") }
        viewModel.schedule = makePublicSchedule(lessons: [
            try makeLanguageLesson(teacherID: 501029, weeks: [1, 3]),
            try makeLanguageLesson(teacherID: 501048, weeks: [2, 4])
        ])
        XCTAssertTrue(viewModel.languageSubgroupOptions.isEmpty)
        XCTAssertFalse(viewModel.showsLanguageSubgroupPicker)
    }

    func testLanguageChoiceAppliesToContinuousTimeline() async throws {
        let defaults = makeDefaults("language-timeline")
        defer { removeDefaults("language-timeline") }
        defaults.set("hidden", forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey)
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        let first = try makeLanguageLesson(teacherID: 501029)
        let second = try makeLanguageLesson(teacherID: 501048)
        viewModel.applyGroupSchedule(makePublicSchedule(lessons: [first, second]), week: 1, groupNumber: "620601")
        viewModel.languageSubgroupTeacherID = 501048
        let monday = try XCTUnwrap(Calendar.current.nextDate(
            after: Date(), matching: DateComponents(weekday: 2), matchingPolicy: .nextTime
        ))
        _ = await viewModel.prepareContinuousTimeline(around: monday)
        XCTAssertFalse(viewModel.continuousTimelineDays.isEmpty)
        XCTAssertTrue(viewModel.continuousTimelineDays.flatMap(\.lessons).allSatisfy { $0.id == second.id })
    }

    func testParallelLessonsHaveDistinctStableIdentities() throws {
        let first = try makeLanguageLesson(teacherID: 501036, weeks: [1, 2, 3, 4])
        let second = try makeLanguageLesson(teacherID: 501048, weeks: [1, 2, 3, 4])
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.id, try makeLanguageLesson(teacherID: 501036, weeks: [4, 3, 2, 1]).id)
        let defaults = makeDefaults("parallel-identities")
        defer { removeDefaults("parallel-identities") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.applyGroupSchedule(makePublicSchedule(lessons: [first, second]), week: 1, groupNumber: "627701")
        viewModel.weekFilter = .all
        XCTAssertEqual(viewModel.filteredDays.flatMap(\.lessons).count, 2)
        XCTAssertEqual(Set(viewModel.filteredDays.flatMap(\.lessons).map(\.id)).count, 2)
    }

    func testOtherSubjectSubgroupsUseCompactFullAndHiddenPresentation() throws {
        let defaults = makeDefaults("subject-presentation")
        defer { removeDefaults("subject-presentation") }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        let first = try makeLanguageLesson(teacherID: 11, subject: "Физическая культура")
        let second = try makeLanguageLesson(teacherID: 22, subject: "Физическая культура")
        viewModel.applyGroupSchedule(makePublicSchedule(lessons: [first, second]), week: 1, groupNumber: "627701")
        let subject = try XCTUnwrap(viewModel.subjectSubgroups.first)
        viewModel.selectTeacher(11, for: subject)
        XCTAssertTrue(viewModel.isOtherSubgroupLesson(second))
        XCTAssertFalse(viewModel.isOtherSubgroupLesson(first))
        for display in ["compact", "full"] {
            defaults.set(display, forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey)
            XCTAssertEqual(viewModel.filteredDays.flatMap(\.lessons).count, 2)
        }
        defaults.set("hidden", forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey)
        XCTAssertEqual(viewModel.filteredDays.flatMap(\.lessons).map(\.id), [first.id])
        XCTAssertFalse(viewModel.shouldKeepLessonForWidget(second))
        viewModel.applyGroupSchedule(makePublicSchedule(lessons: [first, second]), week: 1, groupNumber: "620601")
        XCTAssertNil(viewModel.selectedTeacherID(for: subject))
        viewModel.applyGroupSchedule(makePublicSchedule(lessons: [first, second]), week: 1, groupNumber: "627701")
        XCTAssertEqual(viewModel.selectedTeacherID(for: subject), 11)
        viewModel.selectTeacher(nil, for: subject)
        XCTAssertEqual(viewModel.filteredDays.flatMap(\.lessons).count, 2)
    }

    func testSharedLectureIsExcludedFromIndependentSubgroupChoices() throws {
        let defaults = makeDefaults("shared-lecture")
        defer { removeDefaults("shared-lecture") }
        defaults.set("hidden", forKey: ScheduleDisplayPreferences.otherSubgroupDisplayKey)
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        let first = try makeLanguageLesson(teacherID: 11, subject: "Физика")
        let second = try makeLanguageLesson(teacherID: 22, subject: "Физика")
        let lecture = try makeLanguageLesson(teacherID: 33, subject: "Физика", lessonType: "ЛК")
        viewModel.applyGroupSchedule(makePublicSchedule(lessons: [first, second, lecture]), week: 1, groupNumber: "627701")
        let subject = try XCTUnwrap(viewModel.subjectSubgroups.first)
        XCTAssertEqual(subject.options.map(\.id), [11, 22])
        viewModel.selectTeacher(11, for: subject)
        XCTAssertFalse(viewModel.isOtherSubgroupLesson(lecture))
        XCTAssertTrue(viewModel.shouldKeepLessonForWidget(lecture))
        XCTAssertEqual(Set(viewModel.filteredDays.flatMap(\.lessons).map(\.id)), Set([first.id, lecture.id]))
    }

    private func makeLanguageLesson(teacherID: Int, weeks: [Int] = [], subject: String = "Иностранный язык", lessonType: String = "ПЗ") throws -> DisciplineSchedule {
        let payload: [String: Any] = [
            "subject": subject, "subjectFullName": subject,
            "numSubgroup": 0, "startLessonTime": "09:00", "endLessonTime": "10:35",
            "lessonTypeAbbrev": lessonType, "auditories": ["202-4 к."],
            "weekNumber": weeks, "studentGroups": [],
            "employees": [["id": teacherID, "lastName": "Преподаватель"]]
        ]
        return try JSONDecoder().decode(
            DisciplineSchedule.self, from: JSONSerialization.data(withJSONObject: payload)
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
        "ScheduleLanguageSubgroupTests.\(identifier)"
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

}
