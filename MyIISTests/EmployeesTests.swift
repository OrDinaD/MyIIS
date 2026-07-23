@testable import MyIIS
import XCTest

@MainActor
final class EmployeesTests: XCTestCase {
    func testNormalization() {
        let repository = EmployeesRepository.shared
        XCTAssertEqual(
            repository.normalizeSearch("Малиновская Татьяна Ивановна"),
            "малиновская татьяна ивановна"
        )
        XCTAssertEqual(
            repository.normalizeSearch("Малиновская  Татьяна"),
            "малиновская татьяна"
        )
        XCTAssertEqual(repository.normalizeSearch("Vfkb"), "мали")
        XCTAssertEqual(repository.normalizeSearch("Ёлка"), "елка")
        XCTAssertEqual(repository.normalizeSearch("Иванов-Петров"), "иванов-петров")
    }

    func testDecodingTreeNulls() throws {
        let json = Data(
            """
            {
              "data": {
                "id": 101,
                "typeId": 1,
                "name": "Ректорат",
                "abbrev": "Ректорат",
                "idHead": null,
                "employees": [],
                "code": "1",
                "urlId": "rektorat"
              },
              "children": null
            }
            """.utf8
        )

        let node = try JSONDecoder().decode(DepartmentTreeNodeDTO.self, from: json)
        XCTAssertEqual(node.data.name, "Ректорат")
        XCTAssertNil(node.children)
    }

    func testDecodingSummaryOptionals() throws {
        let json = Data(
            """
            {
              "id": 511804,
              "firstName": "Татьяна",
              "middleName": "Ивановна",
              "lastName": "Малиновская",
              "photoLink": null,
              "degree": "",
              "degreeAbbrev": "",
              "rank": null,
              "email": "",
              "urlId": "t-malinovskaia",
              "calendarId": null,
              "jobPositions": [],
              "chief": true
            }
            """.utf8
        )

        let summary = try JSONDecoder().decode(EmployeeSummaryDTO.self, from: json)
        XCTAssertEqual(summary.firstName, "Татьяна")
        XCTAssertNil(summary.photoLink)
        XCTAssertTrue(summary.chief == true)
        XCTAssertEqual(summary.getFullName(), "Малиновская Татьяна Ивановна")
    }

    func testEmployeeInfoSectionConvertsHTMLToStablePlainText() {
        let section = EmployeeInfoSection(
            idType: 20_005,
            title: "Публикации",
            htmlContent: """
            <p>Первая <strong>публикация</strong>&nbsp;автора.</p>
            <ol><li>Вторая &amp; третья</li><li><a href="https://example.com">Ссылка</a></li></ol>
            """
        )

        XCTAssertEqual(
            section.textContent,
            """
            Первая публикация автора.
            Вторая & третья
            Ссылка
            """
        )
    }

    func testEmployeeInfoSectionHandlesLargeHTMLWithoutAttributedStringImport() {
        let paragraph = "<p>Публикация <strong>БГУИР</strong></p>"
        let section = EmployeeInfoSection(
            idType: 20_005,
            title: "Публикации",
            htmlContent: String(repeating: paragraph, count: 1_000)
        )

        XCTAssertEqual(
            section.textContent.components(separatedBy: .newlines).count,
            1_000
        )
        XCTAssertFalse(section.textContent.contains("<"))
    }
}
