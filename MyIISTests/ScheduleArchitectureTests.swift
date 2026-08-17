//
//  ScheduleArchitectureTests.swift
//  MyIISTests
//
@testable import MyIIS
import SwiftUI
import XCTest

@MainActor
final class ScheduleArchitectureTests: XCTestCase {
    // MARK: - Navigation & Migration Tests

    func testAppTabScheduleIsFirstTab() {
        let firstTab = AppTab.allCases.first
        XCTAssertEqual(firstTab, .schedule)
        XCTAssertEqual(AppTab.schedule.icon, "calendar")
        XCTAssertFalse(AppTab.schedule.title.isEmpty)
    }

    func testAppRouterDefaultStartupTabIsSchedule() {
        XCTAssertTrue(AppRouter.isSectionOrTabEnabled("schedule"))
        XCTAssertTrue(AppRouter.isSectionOrTabEnabled("services"))
        XCTAssertTrue(AppRouter.isSectionOrTabEnabled("others"))
    }

    func testAppRouterNavigateToSchedule() {
        let router = AppRouter.shared
        router.navigate(to: .schedule)
        XCTAssertEqual(router.selectedTab, .schedule)
        XCTAssertTrue(router.servicesPath.isEmpty)
    }

    func testAppRouterHandleDeepLink() {
        let router = AppRouter.shared
        router.selectedTab = .others

        let url = URL(string: "myiis://section/schedule")!
        router.handleURL(url)
        XCTAssertEqual(router.selectedTab, .schedule)

        let shortURL = URL(string: "myiis://schedule")!
        router.handleURL(shortURL)
        XCTAssertEqual(router.selectedTab, .schedule)
    }

    func testAppRouterResetForLogoutSelectsSchedule() {
        let router = AppRouter.shared
        router.selectedTab = .others
        router.resetForLogout()
        XCTAssertEqual(router.selectedTab, .schedule)
    }

    // MARK: - Lesson Color Preferences Tests

    func testLessonTypeCategoryNormalization() {
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "ЛК"), .lecture)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "лекция"), .lecture)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "ПЗ"), .practice)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "практ"), .practice)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "ЛР"), .laboratory)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "лаб"), .laboratory)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "Конс"), .consultation)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "Экзамен"), .exam)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "Зачет"), .exam)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "Зачёт"), .exam)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "дифзачет"), .exam)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: "Мероприятие"), .other)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: nil), .other)
        XCTAssertEqual(LessonTypeCategory.from(lessonTypeAbbrev: ""), .other)
    }

    func testColorHexConversion() {
        let hex = "#34C759"
        let color = Color(hex: hex)
        XCTAssertNotNil(color)
        let convertedHex = color?.toHex()
        XCTAssertNotNil(convertedHex)
    }

    func testScheduleColorPreferencesDefaultColors() {
        ScheduleColorPreferences.resetAllColors()
        for category in LessonTypeCategory.allCases {
            let hex = ScheduleColorPreferences.hexColor(for: category)
            XCTAssertFalse(hex.isEmpty)
            XCTAssertEqual(hex, category.defaultHex)
        }
    }

    // MARK: - Mid Pair Break Calculator Tests

    func testScheduleMidPairBreakCalculatorStandardPair() {
        // Standard 90-minute pair with 5-minute break: 45 min lesson + 5 min break + 45 min lesson = 95 min
        let result = ScheduleMidPairBreakCalculator.resolve(startTime: "09:00", endTime: "10:35")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.startTime, "09:45")
        XCTAssertEqual(result?.endTime, "09:50")
        XCTAssertEqual(result?.compactText, "09:45–09:50")
    }

    func testScheduleMidPairBreakCalculatorInvalidInterval() {
        let result = ScheduleMidPairBreakCalculator.resolve(startTime: "10:00", endTime: "09:00")
        XCTAssertNil(result)
    }

    // MARK: - Pinned & Recent Management Tests

    func testPinnedTeacherCodable() throws {
        let teacher = PinnedTeacher(urlId: "12345-ivanov", name: "Иванов И. И.", photoLink: "https://example.com/photo.jpg")
        let data = try JSONEncoder().encode(teacher)
        let decoded = try JSONDecoder().decode(PinnedTeacher.self, from: data)
        XCTAssertEqual(decoded.urlId, teacher.urlId)
        XCTAssertEqual(decoded.name, teacher.name)
        XCTAssertEqual(decoded.photoLink, teacher.photoLink)
    }

    func testViewModelPinnedGroupsAndTeachers() {
        let suiteName = "test.suite.schedule.architecture"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Could not create isolated UserDefaults")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        XCTAssertTrue(viewModel.pinnedGroupNames.isEmpty)
        XCTAssertTrue(viewModel.pinnedTeachers.isEmpty)

        viewModel.togglePinnedGroupName("123456")
        XCTAssertTrue(viewModel.isGroupPinned("123456"))

        viewModel.togglePinnedGroupName("123456")
        XCTAssertFalse(viewModel.isGroupPinned("123456"))

        let teacher = PinnedTeacher(urlId: "test-teacher", name: "Петров П. П.")
        viewModel.togglePinnedTeacher(teacher)
        XCTAssertTrue(viewModel.isTeacherPinned("test-teacher"))

        viewModel.togglePinnedTeacher(teacher)
        XCTAssertFalse(viewModel.isTeacherPinned("test-teacher"))
    }

    // MARK: - Schedule Display Preferences Tests

    func testScheduleDisplayPreferencesDefaults() {
        XCTAssertEqual(ScheduleCardDensity.regular.rawValue, "regular")
        XCTAssertEqual(ScheduleCardDensity.compact.rawValue, "compact")
        XCTAssertEqual(ScheduleOtherSubgroupDisplay.full.rawValue, "full")
        XCTAssertEqual(ScheduleOtherSubgroupDisplay.compact.rawValue, "compact")
        XCTAssertEqual(ScheduleOtherSubgroupDisplay.hidden.rawValue, "hidden")
    }
}
