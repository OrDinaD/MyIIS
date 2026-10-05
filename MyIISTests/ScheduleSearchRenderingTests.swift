@testable import MyIIS
import SwiftUI
import XCTest

/// Actual SwiftUI rendering with a small captured directory sample, isolated from network and user defaults.
@MainActor
final class ScheduleSearchRenderingTests: XCTestCase {
    func testGroupSearchRendersFacultyRowsAliasesAndLargeType() async throws {
        let suite = "ScheduleSearchRendering.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.groups = try groups()
        viewModel.pinnedGroupNames = ["420604"]
        viewModel.pinnedGroupAliases = ["420604": "Илюха"]
        viewModel.query = ""
        for appearance in [ColorScheme.dark, .light] {
            try await capture(
                ScheduleSearchSheet(viewModel: viewModel, isPresented: .constant(true))
                    .preferredColorScheme(appearance),
                name: "Group search · \(appearance)"
            )
        }
        try await capture(
            ScrollView {
                ScheduleSuggestionsView(
                    groups: viewModel.groups, pinnedGroupNames: [], pinnedGroupAliases: [:],
                    recentGroupNames: [], accountGroupName: nil, showsAllGroups: true,
                    onSelect: { _ in }, onTogglePin: { _ in }, onRenamePinnedGroup: { _ in },
                    onShowAllGroups: {}
                ).padding(16)
            }.background(Color(uiColor: .systemGroupedBackground)).preferredColorScheme(.dark),
            name: "Faculty palette · captured directory"
        )
        try await capture(
            ScheduleSearchSheet(viewModel: viewModel, isPresented: .constant(true))
                .preferredColorScheme(.dark)
                .environment(\.dynamicTypeSize, .accessibility3),
            name: "Group search · large text"
        )
    }

    func testNumberFinderRendersSelectedDigitsAndMatchingGroups() async throws {
        let suite = "ScheduleNumberRendering.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let viewModel = ScheduleServiceViewModel(defaults: defaults)
        viewModel.groups = try groups()
        let model = ScheduleGroupNumberFinderModel()
        model.updateDirectory(viewModel.groups)
        model.select(4)
        model.activePosition = 1
        model.select(2)
        XCTAssertEqual(Set(model.matches.map(\.name)), ["420603", "420604", "421703"])
        try await capture(
            ScheduleGroupNumberFinder(viewModel: viewModel, model: model) { _ in },
            name: "Group number · selected year and faculty"
        )
        model.toggleResults()
        XCTAssertFalse(model.areResultsVisible)
        model.activePosition = 0
        try await capture(
            ScheduleGroupNumberFinder(viewModel: viewModel, model: model) { _ in },
            name: "Group number · hidden results and course picker"
        )
    }

    private func capture<Content: View>(_ content: Content, name: String) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        let controller = UIHostingController(rootView: content.environment(\.locale, Locale(identifier: "ru")))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousWindow?.makeKey()
        }
        try await Task.sleep(for: .milliseconds(500))
        controller.view.layoutIfNeeded()
        let bounds = controller.view.bounds
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
        let image = UIGraphicsImageRenderer(bounds: bounds).image { _ in
            controller.view.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func groups() throws -> [StudyGroup] {
        try JSONDecoder().decode([StudyGroup].self, from: Data(capturedDirectory.utf8))
    }

    // Captured from the public student-groups endpoint on 2 October 2026.
    private let capturedDirectory = """
        [
          {
            "name": "310101",
            "facultyAbbrev": "ФКП",
            "specialityAbbrev": "ИСиТ (ИСиТвОПБ)",
            "course": 4
          },
          {
            "name": "320601",
            "facultyAbbrev": "ФИТУ",
            "specialityAbbrev": "СУИ (АСОИ)",
            "course": 4
          },
          {
            "name": "333701",
            "facultyAbbrev": "ВФ",
            "specialityAbbrev": "СиСИ (СТСН)",
            "course": 4
          },
          {
            "name": "340301",
            "facultyAbbrev": "ФРЭ",
            "specialityAbbrev": "МиН (МиНТиС)",
            "course": 4
          },
          {
            "name": "350501",
            "facultyAbbrev": "ФКСиС",
            "specialityAbbrev": "КИ (ВМСиС)",
            "course": 4
          },
          {
            "name": "361401",
            "facultyAbbrev": "ФИБ",
            "specialityAbbrev": "ИБ (ЗИвТ)",
            "course": 4
          },
          {
            "name": "372301",
            "facultyAbbrev": "ИЭФ",
            "specialityAbbrev": "ИСиТ (ИСиТвЭ)",
            "course": 4
          },
          {
            "name": "420603",
            "facultyAbbrev": "ФИТУ",
            "specialityAbbrev": "СУИ (АСОИ)",
            "course": 3
          },
          {
            "name": "420604",
            "facultyAbbrev": "ФИТУ",
            "specialityAbbrev": "СУИ (АСОИ)",
            "course": 3
          },
          {
            "name": "421703",
            "facultyAbbrev": "ФИТУ",
            "specialityAbbrev": "ИИ",
            "course": 3
          },
          {
            "name": "453503",
            "facultyAbbrev": "ФКСиС",
            "specialityAbbrev": "ИиТП",
            "course": 3
          },
          {
            "name": "473903",
            "facultyAbbrev": "ИЭФ",
            "specialityAbbrev": "ЭЭ (ЭЭБ)",
            "course": 3
          },
          {
            "name": "481570",
            "facultyAbbrev": "ФКТ",
            "specialityAbbrev": "ПИ (ПОКТ)",
            "course": 3
          },
          {
            "name": "520603",
            "facultyAbbrev": "ФИТУ",
            "specialityAbbrev": "СУИ (АСОИ)",
            "course": 2
          }
        ]
        """
}
