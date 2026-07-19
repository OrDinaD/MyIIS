import XCTest
@testable import MyIIS

final class EmployeesTests: XCTestCase {
    
    func testNormalization() {
        let repo = EmployeesRepository.shared
        XCTAssertEqual(repo.normalizeSearch("Малиновская Татьяна Ивановна"), "малиновская татьяна ивановна")
        XCTAssertEqual(repo.normalizeSearch("Малиновская  Татьяна"), "малиновская татьяна")
        XCTAssertEqual(repo.normalizeSearch("Vfkb"), "мали")
        XCTAssertEqual(repo.normalizeSearch("Ёлка"), "елка")
        XCTAssertEqual(repo.normalizeSearch("Иванов-Петров"), "иванов-петров")
    }

    func testDecodingTreeNulls() throws {
        let json = """
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
        """.data(using: .utf8)!
        
        let node = try JSONDecoder().decode(DepartmentTreeNodeDTO.self, from: json)
        XCTAssertEqual(node.data.name, "Ректорат")
        XCTAssertNil(node.children)
    }
    
    func testDecodingSummaryOptionals() throws {
        let json = """
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
        """.data(using: .utf8)!
        
        let summary = try JSONDecoder().decode(EmployeeSummaryDTO.self, from: json)
        XCTAssertEqual(summary.firstName, "Татьяна")
        XCTAssertNil(summary.photoLink)
        XCTAssertTrue(summary.chief == true)
        XCTAssertEqual(summary.getFullName(), "Малиновская Татьяна Ивановна")
    }
}
