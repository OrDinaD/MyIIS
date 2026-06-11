import XCTest
@testable import MyIIS

@MainActor
final class GradebookViewModelTests: XCTestCase {
    
    var viewModel: GradebookViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        let session = URLSession(configuration: .ephemeral)
        viewModel = GradebookViewModel(apiService: APIService(session: session))
    }
    
    override func tearDown() async throws {
        viewModel = nil
        try await super.tearDown()
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
        
        let data = try! JSONSerialization.data(withJSONObject: rootDict)
        viewModel.markbook = try! JSONDecoder().decode(MarkbookResponse.self, from: data)
    }
}
