@testable import MyIIS
import XCTest

@MainActor
final class GradebookViewModelTests: XCTestCase {

    var viewModel: GradebookViewModel!

    override func setUp() async throws {
        try await super.setUp()
        APIService.isDemoMode = false
        clearGradebookCaches()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        viewModel = GradebookViewModel(apiService: APIService(session: session))
    }

    override func tearDown() async throws {
        MockURLProtocol.requestHandler = nil
        viewModel = nil
        APIService.isDemoMode = false
        clearGradebookCaches()
        try await super.tearDown()
    }

    private func clearGradebookCaches() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "gradebook_offline_cache_v1")
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("APIService.responseCache.") {
            defaults.removeObject(forKey: key)
        }

        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.OrDinaD.MyIIS") {
            try? FileManager.default.removeItem(at: containerURL.appendingPathComponent("PayloadStore"))
        }
        if let cachesURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            try? FileManager.default.removeItem(at: cachesURL.appendingPathComponent("PayloadStore"))
        }
    }

    // MARK: - Equivalence Partitioning & Boundary Value Analysis for yearlyAverage

    func testYearlyAverage_OddSemester_PairsWithNextEvenSemester() {
        // Valid class: Odd semester (e.g., 3) -> should pair with 4
        // Boundary value: 1

        setupMockMarkbook(with: [
            "1": [9.0, 10.0],
            "2": [8.0, 9.0]
        ])

        viewModel.selectedSemesterKey = "1"

        // Marks: 9, 10, 8, 9 = 36 / 4 = 9.0
        XCTAssertEqual(viewModel.yearlyAverage ?? -1.0, 9.0, accuracy: 0.001)
    }

    func testYearlyAverage_EvenSemester_PairsWithPreviousOddSemester() {
        // Valid class: Even semester (e.g., 4) -> should pair with 3
        // Boundary value: 2

        setupMockMarkbook(with: [
            "1": [9.0, 10.0],
            "2": [8.0, 9.0]
        ])

        viewModel.selectedSemesterKey = "2"

        // Marks: 9, 10, 8, 9 = 36 / 4 = 9.0
        XCTAssertEqual(viewModel.yearlyAverage ?? -1.0, 9.0, accuracy: 0.001)
    }

    func testYearlyAverage_MissingPairSemester_CalculatesFromAvailable() {
        // Equivalence Class: Missing pair data

        setupMockMarkbook(with: [
            "5": [10.0, 10.0]
            // "6" is missing
        ])

        viewModel.selectedSemesterKey = "5"

        XCTAssertEqual(viewModel.yearlyAverage ?? -1.0, 10.0, accuracy: 0.001)
    }

    func testYearlyAverage_InvalidSemesterKey_ReturnsNil() {
        // Invalid class: not a valid integer string

        setupMockMarkbook(with: [
            "abc": [10.0, 10.0]
        ])

        viewModel.selectedSemesterKey = "abc"

        XCTAssertNil(viewModel.yearlyAverage)
    }

    func testYearlyAverage_NoNumericMarks_ReturnsNil() {
        // Boundary class: Valid semester but no numeric marks

        let json = """
        {
            "number": "123",
            "averageMark": 0.0,
            "markPages": {
                "1": {
                    "averageMark": 0.0,
                    "marks": [
                        {
                            "subject": "PE",
                            "formOfControl": "Зачет",
                            "fullSubject": "",
                            "hours": "",
                            "mark": "зач",
                            "retakesCount": 0
                        }
                    ]
                }
            }
        }
        """
        viewModel.markbook = try? JSONDecoder().decode(MarkbookResponse.self, from: Data(json.utf8))
        viewModel.selectedSemesterKey = "1"

        XCTAssertNil(viewModel.yearlyAverage)
    }

    // MARK: - Equivalence Partitioning for sortSemesterKeys
    // Tested implicitly through `apply` setting `semesterKeys`

    func testSemesterKeys_Sorting_HandlesIntegersCorrectly() {
        let unsortedKeys = ["10", "1", "abc", "2", "11"]
        let sorted = viewModel.sortSemesterKeys(unsortedKeys)

        // "abc" parses as Int.min so it goes first. Then 1, 2, 10, 11
        XCTAssertEqual(sorted, ["abc", "1", "2", "10", "11"])
    }

    // MARK: - Helpers

    private func setupMockMarkbook(with pages: [String: [Double]]) {
        var markPagesDict = [String: Any]()

        for (key, marks) in pages {
            let marksArray = marks.map { val -> [String: Any] in
                return [
                    "subject": "Sub",
                    "formOfControl": "Exam",
                    "fullSubject": "Sub",
                    "hours": "0",
                    "mark": "\(val)",
                    "retakesCount": 0
                ]
            }

            markPagesDict[key] = [
                "averageMark": 0.0,
                "marks": marksArray
            ]
        }

        let rootDict: [String: Any] = [
            "number": "123",
            "averageMark": 0.0,
            "markPages": markPagesDict
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: rootDict)
            viewModel.markbook = try JSONDecoder().decode(MarkbookResponse.self, from: data)
        } catch {
            XCTFail("Failed to create mock markbook: \(error)")
        }
    }

    // MARK: - Formatters & Computed Properties

    func testComputedTextProperties() {
        XCTAssertEqual(viewModel.numberText, "—")
        XCTAssertEqual(viewModel.overallAverageText, "—")
        XCTAssertEqual(viewModel.semesterAverageText, "—")
        XCTAssertEqual(viewModel.yearlyAverageText, "—")
        XCTAssertTrue(viewModel.marksForSelectedSemester.isEmpty)

        setupMockMarkbook(with: ["1": [8.5]])
        viewModel.selectedSemesterKey = "1"

        // Mock sets overall to 0.0, semester to 0.0, and marks to 8.5
        let zeroAverage = 0.0.formatted(.number.precision(.fractionLength(2)))
        let yearlyAverage = 8.5.formatted(.number.precision(.fractionLength(2)))
        XCTAssertEqual(viewModel.numberText, "123")
        XCTAssertEqual(viewModel.overallAverageText, zeroAverage)
        XCTAssertEqual(viewModel.semesterAverageText, zeroAverage)
        XCTAssertEqual(viewModel.yearlyAverageText, yearlyAverage)
        XCTAssertEqual(viewModel.marksForSelectedSemester.count, 1)
    }

    // MARK: - Loading & Networking

    func testLoad_Success() async {
        let markbookJson = """
        {
            "number": "42850012",
            "averageMark": 9.59,
            "markPages": {
                "3": {
                    "averageMark": 10.0,
                    "marks": []
                }
            }
        }
        """

        let profileJson = """
        {
            "course": 3
        }
        """

        MockURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            if url.contains("markbook") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, markbookJson.data(using: .utf8)!)
            } else if url.contains("personal-profile") {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, profileJson.data(using: .utf8)!)
            }
            return (HTTPURLResponse(), Data())
        }

        await viewModel.load()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.markbook?.number, "42850012")
        XCTAssertEqual(viewModel.currentCourse, 3)
        XCTAssertEqual(viewModel.semesterKeys, ["3"])
        XCTAssertEqual(viewModel.selectedSemesterKey, "3")
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoad_Failure() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        await viewModel.load()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.markbook)
    }

    func testLoadIfNeeded_OnlyLoadsOnce() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{}".utf8))
        }

        XCTAssertFalse(viewModel.isLoading)

        await viewModel.loadIfNeeded() // Trigger load

        XCTAssertFalse(viewModel.isLoading) // Loading finished
        XCTAssertNotNil(viewModel.errorMessage) // Will fail decoding empty JSON, but it tried loading

        let previousError = viewModel.errorMessage

        // Second time shouldn't trigger load() again
        MockURLProtocol.requestHandler = { _ in
            XCTFail("Should not be called again")
            return (HTTPURLResponse(), Data())
        }

        await viewModel.loadIfNeeded()
        XCTAssertEqual(viewModel.errorMessage, previousError) // State unchanged
    }

    func testSelectSemester() {
        viewModel.semesterKeys = ["1", "2", "3"]
        viewModel.selectedSemesterKey = "1"

        viewModel.selectSemester("2")
        XCTAssertEqual(viewModel.selectedSemesterKey, "2")

        viewModel.selectSemester("99") // invalid
        XCTAssertEqual(viewModel.selectedSemesterKey, "2") // remains unchanged
    }

    func testRefresh() async {
        let markbookJson = """
        {
            "number": "555",
            "averageMark": 8.0,
            "markPages": {}
        }
        """
        let profileJson = """
        { "course": 2 }
        """

        MockURLProtocol.requestHandler = { request in
            let url = request.url!.absoluteString
            if url.contains("markbook") {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, markbookJson.data(using: .utf8)!)
            } else {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, profileJson.data(using: .utf8)!)
            }
        }

        await viewModel.refresh()
        XCTAssertEqual(viewModel.markbook?.number, "555")
        XCTAssertEqual(viewModel.currentCourse, 2)
    }

    func testCacheLoading() async {
        let markbook = MarkbookResponse(number: "999", averageMark: 10.0, markPages: [:])
        GradebookCacheStore.save(markbook: markbook, currentCourse: 4, updatedAt: Date())

        // New instance should load from cache
        let cachedViewModel = GradebookViewModel(apiService: APIService(session: URLSession.shared))

        XCTAssertEqual(cachedViewModel.markbook?.number, "999")
        XCTAssertEqual(cachedViewModel.currentCourse, 4)
    }

    func testStaleDataWarning() async {
        let markbookJson = """
        {
            "number": "555",
            "averageMark": 8.0,
            "markPages": {}
        }
        """
        let profileJson = """
        { "course": 2 }
        """

        // 1. Initial success
        MockURLProtocol.requestHandler = { request in
            if request.url!.absoluteString.contains("markbook") {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, markbookJson.data(using: .utf8)!)
            } else {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, profileJson.data(using: .utf8)!)
            }
        }
        await viewModel.load()
        XCTAssertNotNil(viewModel.markbook)
        viewModel.lastUpdateTime = Date().addingTimeInterval(-6 * 60)
        clearGradebookCaches()

        // 2. Refresh fails
        MockURLProtocol.requestHandler = { request in
            return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
        }
        await viewModel.refresh()

        XCTAssertTrue(viewModel.isShowingStaleDataWarning)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.markbook) // Keeps old data
    }

    // MARK: - Semester Selection Tests

    func testResolveDefaultSemesterKey_AutumnSemester_SelectsOddSemester() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let autumnDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15))!

        let markPages: [String: MarkbookSemester] = [
            "1": MarkbookSemester(averageMark: 8.0, marks: []),
            "2": MarkbookSemester(averageMark: 8.5, marks: []),
            "3": MarkbookSemester(averageMark: 0.0, marks: []),
            "4": MarkbookSemester(averageMark: 0.0, marks: [])
        ]
        let keys = ["1", "2", "3", "4"]

        let selected = GradebookViewModel.resolveDefaultSemesterKey(
            from: keys,
            markPages: markPages,
            currentCourse: 2,
            referenceDate: autumnDate,
            calendar: calendar
        )
        XCTAssertEqual(selected, "3", "For 2nd year student in autumn (October), semester 3 should be selected, not 4")
    }

    func testResolveDefaultSemesterKey_SpringSemester_SelectsEvenSemester() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let springDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!

        let markPages: [String: MarkbookSemester] = [
            "1": MarkbookSemester(averageMark: 8.0, marks: []),
            "2": MarkbookSemester(averageMark: 8.5, marks: []),
            "3": MarkbookSemester(averageMark: 9.0, marks: []),
            "4": MarkbookSemester(averageMark: 0.0, marks: [])
        ]
        let keys = ["1", "2", "3", "4"]

        let selected = GradebookViewModel.resolveDefaultSemesterKey(
            from: keys,
            markPages: markPages,
            currentCourse: 2,
            referenceDate: springDate,
            calendar: calendar
        )
        XCTAssertEqual(selected, "4", "For 2nd year student in spring (March), semester 4 should be selected")
    }

    func testResolveDefaultSemesterKey_FutureSemesterCreated_SelectsCurrentExpectedSemester() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let autumnDate = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1))!

        let markPages: [String: MarkbookSemester] = [
            "1": MarkbookSemester(averageMark: 8.0, marks: []),
            "2": MarkbookSemester(averageMark: 8.5, marks: []),
            "3": MarkbookSemester(averageMark: 0.0, marks: []),
            "4": MarkbookSemester(averageMark: 0.0, marks: []),
            "5": MarkbookSemester(averageMark: 0.0, marks: [])
        ]
        let keys = ["1", "2", "3", "4", "5"]

        let selected = GradebookViewModel.resolveDefaultSemesterKey(
            from: keys,
            markPages: markPages,
            currentCourse: 2,
            referenceDate: autumnDate,
            calendar: calendar
        )
        XCTAssertEqual(selected, "3", "Backend future semester 5 must not be selected over current semester 3")
    }

    func testResolveDefaultSemesterKey_MissingCurrentSemester_SelectsLatestWithMarks() {
        let dummyMark = MarkbookMark(
            subject: "Math", formOfControl: "Exam", fullSubject: "Math",
            hours: "10", credits: nil, mark: "9", date: "01.01.2025",
            teacher: nil, commonMark: nil, commonRetakes: nil, retakesCount: 0
        )
        let markPages: [String: MarkbookSemester] = [
            "1": MarkbookSemester(averageMark: 8.0, marks: [dummyMark]),
            "2": MarkbookSemester(averageMark: 8.5, marks: [dummyMark])
        ]
        let keys = ["1", "2"]

        let selected = GradebookViewModel.resolveDefaultSemesterKey(
            from: keys,
            markPages: markPages,
            currentCourse: 4
        )
        XCTAssertEqual(selected, "2", "Fallback should select the latest semester with actual marks")
    }
}
